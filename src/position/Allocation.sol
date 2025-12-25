// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.31;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IERC7579Account} from "erc7579/interfaces/IERC7579Account.sol";
import {IExecutor, IHook, MODULE_TYPE_EXECUTOR, MODULE_TYPE_HOOK} from "erc7579/interfaces/IERC7579Module.sol";
import {ModeLib, ModeCode, ModePayload, CALLTYPE_SINGLE, EXECTYPE_TRY, MODE_DEFAULT} from "erc7579/lib/ModeLib.sol";
import {ExecutionLib} from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import {CoreContract} from "../utils/CoreContract.sol";
import {Error} from "../utils/Error.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {Precision} from "../utils/Precision.sol";
import {PositionUtils} from "./utils/PositionUtils.sol";

contract Allocation is CoreContract, IExecutor, IHook {
    struct Config {
        uint maxPuppetList;
        uint transferOutGasLimit;
    }

    Config public config;

    // Balance tracking
    mapping(bytes32 => mapping(address => uint)) public allocationBalance;
    mapping(bytes32 => uint) public totalAllocation;
    mapping(bytes32 => uint) public totalUtilization;

    // Epoch system for lazy utilization calculation
    mapping(bytes32 => uint) public currentEpoch;
    mapping(bytes32 => mapping(uint => uint)) public epochRemaining;
    mapping(bytes32 => mapping(address => uint)) public userEpoch;
    mapping(bytes32 => mapping(address => uint)) public userRemainingCheckpoint;
    mapping(bytes32 => mapping(address => uint)) public userAllocationSnapshot;

    // Settlement distribution
    mapping(bytes32 => uint) public cumulativeSettlementPerUtilization;
    mapping(bytes32 => mapping(address => uint)) public userSettlementCheckpoint;
    mapping(bytes32 => mapping(uint => uint)) public epochFirstUtilizationCumulative;

    // Subaccount registry
    mapping(bytes32 => IERC7579Account) public subaccountMap;
    mapping(bytes32 => uint) public subaccountRecordedBalance;
    mapping(IERC7579Account => IERC20[]) public masterCollateralList;

    constructor(IAuthority _authority, Config memory _config) CoreContract(_authority, abi.encode(_config)) {}

    // ===================== Views =====================

    function getConfig() external view returns (Config memory) {
        return config;
    }

    function getUtilization(bytes32 _key, address _user) public view returns (uint) {
        uint _snapshot = userAllocationSnapshot[_key][_user];
        if (_snapshot == 0) return 0;

        uint _userEpoch = userEpoch[_key][_user];
        uint _currEpoch = currentEpoch[_key];
        if (_userEpoch < _currEpoch) return _snapshot;

        uint _checkpoint = userRemainingCheckpoint[_key][_user];
        uint _current = epochRemaining[_key][_currEpoch];
        if (_current >= _checkpoint) return 0;

        return (_snapshot * (_checkpoint - _current)) / _checkpoint;
    }

    function getAllocation(bytes32 _key, address _user) external view returns (uint) {
        uint _allocation = allocationBalance[_key][_user];
        uint _utilized = getUtilization(_key, _user);
        return _utilized >= _allocation ? 0 : _allocation - _utilized;
    }

    function pendingSettlement(bytes32 _key, address _user) external view returns (uint) {
        return pendingSettlement(_key, _user, getUtilization(_key, _user));
    }

    function pendingSettlement(bytes32 _key, address _user, uint _utilization) public view returns (uint) {
        if (_utilization == 0) return 0;

        uint _cumulative = cumulativeSettlementPerUtilization[_key];
        uint _checkpoint = userSettlementCheckpoint[_key][_user];

        // First claim - use epoch baseline (set at first utilization)
        if (_checkpoint == 0) {
            _checkpoint = epochFirstUtilizationCumulative[_key][userEpoch[_key][_user]];
        }

        if (_cumulative <= _checkpoint) return 0;

        return Precision.applyFactor(_cumulative - _checkpoint, _utilization);
    }

    // ===================== ERC-7579 Module =====================

    function isModuleType(uint256 moduleTypeId) external pure returns (bool) {
        return moduleTypeId == MODULE_TYPE_EXECUTOR || moduleTypeId == MODULE_TYPE_HOOK;
    }

    function isInitialized(address _smartAccount) external view returns (bool) {
        return masterCollateralList[IERC7579Account(_smartAccount)].length > 0;
    }

    function onInstall(bytes calldata) external {}

    function onUninstall(bytes calldata) external {
        IERC7579Account _master = IERC7579Account(msg.sender);
        bool _bothInstalled = _master.isModuleInstalled(MODULE_TYPE_EXECUTOR, address(this), "")
            && _master.isModuleInstalled(MODULE_TYPE_HOOK, address(this), "");

        if (_bothInstalled) {
            IERC20[] memory _tokens = masterCollateralList[_master];
            for (uint _i = 0; _i < _tokens.length; ++_i) {
                bytes32 _key = PositionUtils.getMatchingKey(_tokens[_i], address(_master));
                uint _utilized = totalUtilization[_key];
                if (_utilized > 0) revert Error.Allocation__ActiveUtilization(_utilized);
            }
            delete masterCollateralList[_master];
        }
    }

    // ===================== Hooks =====================

    function preCheck(address, uint256, bytes calldata _callData) external returns (bytes memory) {
        IERC7579Account _subaccount = IERC7579Account(msg.sender);
        address _master = address(_subaccount);
        IERC20[] memory _tokens = masterCollateralList[_subaccount];

        for (uint _i = 0; _i < _tokens.length; ++_i) {
            _settle(PositionUtils.getMatchingKey(_tokens[_i], _master), _tokens[_i]);
        }
        return _callData;
    }

    function postCheck(bytes calldata _hookData) external {
        IERC7579Account _subaccount = IERC7579Account(msg.sender);
        address _master = address(_subaccount);
        IERC20[] memory _tokens = masterCollateralList[_subaccount];

        for (uint _i = 0; _i < _tokens.length; ++_i) {
            IERC20 _token = _tokens[_i];
            bytes32 _key = PositionUtils.getMatchingKey(_token, _master);

            uint _recorded = subaccountRecordedBalance[_key];
            if (_recorded == 0) continue;

            uint _actual = _token.balanceOf(address(_subaccount));
            if (_actual >= _recorded) continue;

            uint _utilized = _recorded - _actual;
            uint _totalAlloc = totalAllocation[_key];
            if (_totalAlloc == 0) revert Error.Allocation__ZeroAllocation();

            uint _epoch = currentEpoch[_key];
            uint _remaining = epochRemaining[_key][_epoch];

            // First utilization of epoch - snapshot cumulative as baseline
            if (_remaining == Precision.FLOAT_PRECISION) {
                epochFirstUtilizationCumulative[_key][_epoch] = cumulativeSettlementPerUtilization[_key];
            }

            uint _newRemaining = (_remaining * (_totalAlloc - _utilized)) / _totalAlloc;
            epochRemaining[_key][_epoch] = _newRemaining;

            uint _newTotalUtil = totalUtilization[_key] + _utilized;
            uint _allocated = _totalAlloc - _utilized;
            totalUtilization[_key] = _newTotalUtil;
            totalAllocation[_key] = _allocated;
            subaccountRecordedBalance[_key] = _actual;

            _logEvent("Action", abi.encode(_key, _token, _subaccount, _utilized, _newTotalUtil, _allocated, _hookData));
        }
    }

    // ===================== External =====================

    function allocate(
        IERC20 _collateralToken,
        address _masterAddr,
        uint _masterAllocation,
        address[] calldata _puppetList,
        uint[] calldata _allocationList
    ) external auth {
        IERC7579Account _master = IERC7579Account(_masterAddr);
        bool _bothInstalled = _master.isModuleInstalled(MODULE_TYPE_EXECUTOR, address(this), "")
            && _master.isModuleInstalled(MODULE_TYPE_HOOK, address(this), "");
        if (!_bothInstalled) revert Error.Allocation__UnregisteredSubaccount();

        uint _puppetCount = _puppetList.length;
        if (_puppetCount > config.maxPuppetList) {
            revert Error.Allocation__PuppetListTooLarge(_puppetCount, config.maxPuppetList);
        }
        if (_puppetCount != _allocationList.length) {
            revert Error.Allocation__PuppetListTooLarge(_puppetCount, _allocationList.length);
        }

        bytes32 _key = PositionUtils.getMatchingKey(_collateralToken, _masterAddr);
        uint _cumulative = _settle(_key, _collateralToken);
        uint _epoch = currentEpoch[_key];
        if (epochRemaining[_key][_epoch] == 0) {
            currentEpoch[_key] = ++_epoch;
            epochRemaining[_key][_epoch] = Precision.FLOAT_PRECISION;
        }

        if (subaccountMap[_key] == IERC7579Account(address(0))) {
            subaccountMap[_key] = _master;
            masterCollateralList[_master].push(_collateralToken);
        }

        // Track master's own allocation (skin in the game)
        uint _masterUtilized = 0;
        if (_masterAllocation > 0) {
            uint _allocation = allocationBalance[_key][_masterAddr] += _masterAllocation;
            _masterUtilized = getUtilization(_key, _masterAddr);
            if (_masterUtilized == 0) {
                userEpoch[_key][_masterAddr] = _epoch;
                userRemainingCheckpoint[_key][_masterAddr] = epochRemaining[_key][_epoch];
                userAllocationSnapshot[_key][_masterAddr] = _allocation;
            }
        }

        uint _total = _masterAllocation;
        uint[] memory _puppetUtilList = new uint[](_puppetCount);

        for (uint _i = 0; _i < _puppetCount; ++_i) {
            address _puppet = _puppetList[_i];
            uint _amount = _allocationList[_i];
            if (_amount == 0) continue;

            bytes memory _result = _executeFromExecutor(
                _master,
                _puppet,
                abi.encodeCall(
                    IERC7579Account.execute,
                    (ModeLib.encodeSimpleSingle(), ExecutionLib.encodeSingle(address(_collateralToken), 0, abi.encodeCall(IERC20.transfer, (_masterAddr, _amount))))
                )
            );

            if (_result.length > 0) continue;

            uint _allocation = allocationBalance[_key][_puppet] += _amount;
            uint _utilized = getUtilization(_key, _puppet);
            if (_utilized == 0) {
                // New user - set epoch checkpoints but NOT settlement checkpoint
                // Settlement checkpoint stays 0 to indicate "use epochFirstUtilizationCumulative"
                userEpoch[_key][_puppet] = _epoch;
                userRemainingCheckpoint[_key][_puppet] = epochRemaining[_key][_epoch];
                userAllocationSnapshot[_key][_puppet] = _allocation;
            }

            _puppetUtilList[_i] = _utilized;
            _total += _amount;
        }

        if (_total == 0) revert Error.Allocation__ZeroAllocation();

        totalAllocation[_key] += _total;
        subaccountRecordedBalance[_key] += _total;

        _logEvent("Allocate", abi.encode(
            _key, _collateralToken, _master, _masterAllocation, _masterUtilized, _total, _puppetList, _allocationList, _puppetUtilList
        ));
    }

    function withdraw(IERC20 _token, bytes32 _key, address _user, uint _amount) external auth {
        uint _cumulative = _settle(_key, _token);
        uint _epoch = currentEpoch[_key];
        uint _utilized = getUtilization(_key, _user);
        uint _allocation = allocationBalance[_key][_user];
        uint _realized = 0;

        if (_utilized > 0) {
            uint _checkpoint = userSettlementCheckpoint[_key][_user];

            // First claim - use epoch baseline (set at first utilization)
            if (_checkpoint == 0) {
                _checkpoint = epochFirstUtilizationCumulative[_key][userEpoch[_key][_user]];
            }

            if (_cumulative <= _checkpoint) revert Error.Allocation__UtilizationNotSettled(_utilized);

            _realized = Precision.applyFactor(_cumulative - _checkpoint, _utilized);
            totalUtilization[_key] -= _utilized;
            totalAllocation[_key] += _realized;
            _allocation = _allocation + _realized - _utilized;
        }

        if (_amount > 0) {
            if (_allocation < _amount) revert Error.Allocation__InsufficientAllocation(_allocation, _amount);
            _allocation -= _amount;
            totalAllocation[_key] -= _amount;
        }

        allocationBalance[_key][_user] = _allocation;
        _updateUserCheckpoints(_key, _user, _epoch, _cumulative, _allocation);

        if (_amount > 0) {
            bytes memory _result = _executeFromExecutor(
                subaccountMap[_key], address(_token), config.transferOutGasLimit, abi.encodeCall(IERC20.transfer, (_user, _amount))
            );
            if (_result.length > 0 && !abi.decode(_result, (bool))) {
                revert Error.Allocation__TransferFailed();
            }
            subaccountRecordedBalance[_key] -= _amount;

            _logEvent("Withdraw", abi.encode(_key, _token, _user, _amount, _realized, _utilized, _allocation));
        }
    }

    // ===================== Internal =====================

    function _executeFromExecutor(IERC7579Account _from, address _to, bytes memory _data) internal returns (bytes memory) {
        ModeCode _mode = ModeLib.encode(CALLTYPE_SINGLE, EXECTYPE_TRY, MODE_DEFAULT, ModePayload.wrap(0x00));
        return _from.executeFromExecutor(_mode, ExecutionLib.encodeSingle(_to, 0, _data))[0];
    }

    function _executeFromExecutor(IERC7579Account _from, address _to, uint _gas, bytes memory _data) internal returns (bytes memory) {
        return _from.executeFromExecutor{gas: _gas}(ModeLib.encodeSimpleSingle(), ExecutionLib.encodeSingle(_to, 0, _data))[0];
    }

    function _settle(bytes32 _key, IERC20 _token) internal returns (uint _cumulative) {
        uint _totalUtil = totalUtilization[_key];
        _cumulative = cumulativeSettlementPerUtilization[_key];
        if (_totalUtil == 0) return _cumulative;

        address _subaccount = address(subaccountMap[_key]);
        uint _actual = _token.balanceOf(_subaccount);
        uint _recorded = subaccountRecordedBalance[_key];
        if (_actual <= _recorded) return _cumulative;

        uint _settled = _actual - _recorded;
        subaccountRecordedBalance[_key] = _actual;
        _cumulative += Precision.toFactor(_settled, _totalUtil);
        cumulativeSettlementPerUtilization[_key] = _cumulative;

        _logEvent("Settle", abi.encode(_key, _token, _subaccount, _settled, _totalUtil, _cumulative));
    }

    function _updateUserCheckpoints(bytes32 _key, address _user, uint _epoch, uint _cumulative, uint _allocation) internal {
        userEpoch[_key][_user] = _epoch;
        userRemainingCheckpoint[_key][_user] = epochRemaining[_key][_epoch];
        userAllocationSnapshot[_key][_user] = _allocation;
        userSettlementCheckpoint[_key][_user] = _cumulative;
    }

    function _setConfig(bytes memory _data) internal override {
        Config memory _config = abi.decode(_data, (Config));
        if (_config.maxPuppetList == 0) revert("Invalid max puppet list");
        if (_config.transferOutGasLimit == 0) revert("Invalid transfer out gas limit");
        config = _config;
    }
}
