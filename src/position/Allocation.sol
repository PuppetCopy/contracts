// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.31;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {CoreContract} from "../utils/CoreContract.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {IERC7579Account} from "erc7579/interfaces/IERC7579Account.sol";
import {IExecutor, IHook, MODULE_TYPE_EXECUTOR, MODULE_TYPE_HOOK} from "erc7579/interfaces/IERC7579Module.sol";
import {ModeLib, ModePayload, CALLTYPE_SINGLE, EXECTYPE_TRY, MODE_DEFAULT} from "erc7579/lib/ModeLib.sol";
import {ExecutionLib} from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import {Error} from "./../utils/Error.sol";
import {Precision} from "./../utils/Precision.sol";
import {PositionUtils} from "./utils/PositionUtils.sol";

contract Allocation is CoreContract, IExecutor, IHook {
    using SafeERC20 for IERC20;

    struct Config {
        uint maxPuppetList;
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

    // Subaccount registry
    mapping(bytes32 => IERC7579Account) public subaccountMap;
    mapping(bytes32 => uint) public subaccountRecordedBalance;
    mapping(IERC7579Account => address) public subaccountTraderMap;
    mapping(IERC7579Account => IERC20[]) internal _subaccountTokenList;
    mapping(IERC7579Account => bool) public registeredSubaccount;

    constructor(IAuthority _authority, Config memory _config) CoreContract(_authority, abi.encode(_config)) {}

    // ===================== Views =====================

    function getConfig() external view returns (Config memory) {
        return config;
    }

    function getSubaccountTokenList(IERC7579Account _subaccount) external view returns (IERC20[] memory) {
        return _subaccountTokenList[_subaccount];
    }

    function getUserUtilization(bytes32 _key, address _user) public view returns (uint) {
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

    function getAvailableAllocation(bytes32 _key, address _user) external view returns (uint) {
        uint _allocation = allocationBalance[_key][_user];
        uint _utilization = getUserUtilization(_key, _user);
        return _utilization >= _allocation ? 0 : _allocation - _utilization;
    }

    function pendingSettlement(bytes32 _key, address _user) external view returns (uint) {
        return pendingSettlement(_key, _user, getUserUtilization(_key, _user));
    }

    function pendingSettlement(bytes32 _key, address _user, uint _utilization) public view returns (uint) {
        if (_utilization == 0) return 0;

        uint _cumulative = cumulativeSettlementPerUtilization[_key];
        uint _checkpoint = userSettlementCheckpoint[_key][_user];
        if (_cumulative <= _checkpoint) return 0;

        return Precision.applyFactor(_cumulative - _checkpoint, _utilization);
    }

    // ===================== ERC-7579 Module =====================

    function isModuleType(uint256 moduleTypeId) external pure returns (bool) {
        return moduleTypeId == MODULE_TYPE_EXECUTOR || moduleTypeId == MODULE_TYPE_HOOK;
    }

    function isInitialized(address _smartAccount) external view returns (bool) {
        return registeredSubaccount[IERC7579Account(_smartAccount)];
    }

    function onInstall(bytes calldata) external {
        IERC7579Account _trader = IERC7579Account(msg.sender);
        bool _bothInstalled = _trader.isModuleInstalled(MODULE_TYPE_EXECUTOR, address(this), "")
            && _trader.isModuleInstalled(MODULE_TYPE_HOOK, address(this), "");

        if (_bothInstalled) {
            registeredSubaccount[_trader] = true;
        }
    }

    function onUninstall(bytes calldata) external {
        IERC7579Account _trader = IERC7579Account(msg.sender);
        bool _bothInstalled = _trader.isModuleInstalled(MODULE_TYPE_EXECUTOR, address(this), "")
            && _trader.isModuleInstalled(MODULE_TYPE_HOOK, address(this), "");

        if (_bothInstalled) {
            IERC20[] memory _tokens = _subaccountTokenList[_trader];
            for (uint _i = 0; _i < _tokens.length; ++_i) {
                bytes32 _key = PositionUtils.getTraderMatchingKey(_tokens[_i], subaccountTraderMap[_trader]);
                uint _util = totalUtilization[_key];
                if (_util > 0) revert Error.Allocation__ActiveUtilization(_util);
            }
            delete registeredSubaccount[_trader];
        }
    }

    // ===================== Hooks =====================

    function preCheck(address, uint256, bytes calldata callData) external returns (bytes memory) {
        IERC7579Account _subaccount = IERC7579Account(msg.sender);
        address _trader = subaccountTraderMap[_subaccount];
        IERC20[] memory _tokens = _subaccountTokenList[_subaccount];

        for (uint _i = 0; _i < _tokens.length; ++_i) {
            _settle(PositionUtils.getTraderMatchingKey(_tokens[_i], _trader), _tokens[_i]);
        }
        return callData;
    }

    function postCheck(bytes calldata hookData) external {
        IERC7579Account _subaccount = IERC7579Account(msg.sender);
        address _trader = subaccountTraderMap[_subaccount];
        IERC20[] memory _tokens = _subaccountTokenList[_subaccount];

        for (uint _i = 0; _i < _tokens.length; ++_i) {
            IERC20 _token = _tokens[_i];
            bytes32 _key = PositionUtils.getTraderMatchingKey(_token, _trader);

            uint _recorded = subaccountRecordedBalance[_key];
            if (_recorded == 0) continue;

            uint _actual = _token.balanceOf(address(_subaccount));
            if (_actual >= _recorded) continue;

            _utilize(_key, _recorded - _actual, hookData);
        }
    }

    // ===================== Allocate =====================

    function allocate(
        IERC20 _collateralToken,
        address _traderAddr,
        uint _traderAllocation,
        address[] calldata _puppetList,
        uint[] calldata _allocationList
    ) external auth {
        IERC7579Account _trader = IERC7579Account(_traderAddr);
        if (!registeredSubaccount[_trader]) revert Error.Allocation__UnregisteredSubaccount();

        uint _puppetCount = _puppetList.length;
        if (_puppetCount > config.maxPuppetList) {
            revert Error.Allocation__PuppetListTooLarge(_puppetCount, config.maxPuppetList);
        }
        if (_puppetCount != _allocationList.length) {
            revert Error.Allocation__PuppetListTooLarge(_puppetCount, _allocationList.length);
        }

        bytes32 _key = PositionUtils.getTraderMatchingKey(_collateralToken, _traderAddr);
        _settle(_key, _collateralToken);
        _initEpochIfNeeded(_key);
        _registerTraderIfNeeded(_key, _trader, _traderAddr, _collateralToken);

        uint _puppetTotal = 0;
        uint[] memory _puppetUtilList = new uint[](_puppetCount);

        for (uint _i = 0; _i < _puppetCount; ++_i) {
            address _puppet = _puppetList[_i];
            uint _amount = _allocationList[_i];
            if (_amount == 0) continue;

            bytes memory _execution = abi.encodeWithSelector(
                IERC7579Account.execute.selector,
                ModeLib.encodeSimpleSingle(),
                ExecutionLib.encodeSingle(address(_collateralToken), 0, abi.encodeCall(IERC20.transfer, (_traderAddr, _amount)))
            );

            bytes[] memory _result = _trader.executeFromExecutor(
                ModeLib.encode(CALLTYPE_SINGLE, EXECTYPE_TRY, MODE_DEFAULT, ModePayload.wrap(0x00)),
                ExecutionLib.encodeSingle(_puppet, 0, _execution)
            );

            if (_result[0].length > 0) continue;

            uint _newAlloc = allocationBalance[_key][_puppet] + _amount;
            allocationBalance[_key][_puppet] = _newAlloc;

            uint _util = getUserUtilization(_key, _puppet);
            if (_util == 0) _updateUserCheckpoints(_key, _puppet, _newAlloc);

            _puppetUtilList[_i] = _util;
            _puppetTotal += _amount;
        }

        uint _traderUtil = 0;
        if (_traderAllocation > 0) {
            uint _newAlloc = allocationBalance[_key][_traderAddr] + _traderAllocation;
            allocationBalance[_key][_traderAddr] = _newAlloc;
            _traderUtil = getUserUtilization(_key, _traderAddr);
            if (_traderUtil == 0) _updateUserCheckpoints(_key, _traderAddr, _newAlloc);
        }

        uint _total = _traderAllocation + _puppetTotal;
        if (_total == 0) revert Error.Allocation__ZeroAllocation();

        totalAllocation[_key] += _total;
        subaccountRecordedBalance[_key] += _total;

        _logEvent("Allocate", abi.encode(
            _key, _collateralToken, _trader, _traderAllocation, _traderUtil,
            _puppetTotal, _total, _puppetList, _allocationList, _puppetUtilList
        ));
    }

    // ===================== Utilize =====================

    function utilize(bytes32 _key, uint _utilization, bytes calldata _calldata) external auth {
        _utilize(_key, _utilization, _calldata);
    }

    function _utilize(bytes32 _key, uint _utilization, bytes calldata _calldata) internal {
        uint _totalAlloc = totalAllocation[_key];
        if (_totalAlloc == 0) revert Error.Allocation__ZeroAllocation();

        uint _epoch = currentEpoch[_key];
        uint _remaining = epochRemaining[_key][_epoch];
        uint _newRemaining = (_remaining * (_totalAlloc - _utilization)) / _totalAlloc;
        epochRemaining[_key][_epoch] = _newRemaining;

        uint _newTotalUtil = totalUtilization[_key] + _utilization;
        uint _newTotalAlloc = _totalAlloc - _utilization;
        totalUtilization[_key] = _newTotalUtil;
        totalAllocation[_key] = _newTotalAlloc;
        subaccountRecordedBalance[_key] -= _utilization;

        _logEvent("Utilize", abi.encode(_key, _epoch, _utilization, _newRemaining, _newTotalUtil, _newTotalAlloc, _calldata));
    }

    // ===================== Withdraw =====================

    function withdraw(IERC20 _token, bytes32 _key, address _user, uint _amount) external auth {
        uint _cumulative = _settle(_key, _token);
        uint _utilization = getUserUtilization(_key, _user);
        uint _allocation = allocationBalance[_key][_user];
        uint _realized = 0;

        if (_utilization > 0) {
            uint _checkpoint = userSettlementCheckpoint[_key][_user];
            if (_cumulative <= _checkpoint) revert Error.Allocation__UtilizationNotSettled(_utilization);

            _realized = Precision.applyFactor(_cumulative - _checkpoint, _utilization);
            totalUtilization[_key] -= _utilization;
            totalAllocation[_key] += _realized;
            _allocation = _allocation + _realized - _utilization;
        }

        if (_amount == 0) {
            allocationBalance[_key][_user] = _allocation;
            _updateUserCheckpoints(_key, _user, _allocation);
            return;
        }

        if (_allocation < _amount) revert Error.Allocation__InsufficientAllocation(_allocation, _amount);

        uint _newAlloc = _allocation - _amount;
        allocationBalance[_key][_user] = _newAlloc;
        totalAllocation[_key] -= _amount;
        _updateUserCheckpoints(_key, _user, _newAlloc);

        _token.safeTransferFrom(address(subaccountMap[_key]), _user, _amount);
        subaccountRecordedBalance[_key] -= _amount;

        _logEvent("Withdraw", abi.encode(_key, _token, _user, _amount, _realized, _utilization, _newAlloc));
    }

    // ===================== Internal =====================

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

    function _initEpochIfNeeded(bytes32 _key) internal {
        uint _epoch = currentEpoch[_key];
        if (epochRemaining[_key][_epoch] != 0) return;

        bool _firstInit = _epoch == 0 && totalUtilization[_key] == 0 && totalAllocation[_key] == 0;
        if (_firstInit) {
            epochRemaining[_key][0] = Precision.FLOAT_PRECISION;
        } else {
            currentEpoch[_key] = ++_epoch;
            epochRemaining[_key][_epoch] = Precision.FLOAT_PRECISION;
        }
    }

    function _registerTraderIfNeeded(bytes32 _key, IERC7579Account _trader, address _traderAddr, IERC20 _token) internal {
        if (subaccountMap[_key] != IERC7579Account(address(0))) return;

        subaccountMap[_key] = _trader;
        subaccountTraderMap[_trader] = _traderAddr;
        _subaccountTokenList[_trader].push(_token);
    }

    function _updateUserCheckpoints(bytes32 _key, address _user, uint _allocation) internal {
        uint _epoch = currentEpoch[_key];
        userEpoch[_key][_user] = _epoch;
        userRemainingCheckpoint[_key][_user] = epochRemaining[_key][_epoch];
        userAllocationSnapshot[_key][_user] = _allocation;
        userSettlementCheckpoint[_key][_user] = cumulativeSettlementPerUtilization[_key];
    }

    function _setConfig(bytes memory _data) internal override {
        Config memory _config = abi.decode(_data, (Config));
        if (_config.maxPuppetList == 0) revert("Invalid max puppet list");
        config = _config;
    }
}
