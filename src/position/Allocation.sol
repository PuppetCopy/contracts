// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC7579Account} from "modulekit/accounts/common/interfaces/IERC7579Account.sol";
import {IExecutor, IHook, MODULE_TYPE_EXECUTOR, MODULE_TYPE_HOOK} from "modulekit/accounts/common/interfaces/IERC7579Module.sol";
import {ModeLib, ModeCode, ModePayload, CallType, CALLTYPE_SINGLE, CALLTYPE_BATCH, CALLTYPE_DELEGATECALL, EXECTYPE_TRY, MODE_DEFAULT} from "modulekit/accounts/common/lib/ModeLib.sol";
import {ExecutionLib, Execution} from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import {CoreContract} from "../utils/CoreContract.sol";
import {Error} from "../utils/Error.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {Precision} from "../utils/Precision.sol";
import {PositionUtils} from "./utils/PositionUtils.sol";
import {INpvReader} from "./interface/INpvReader.sol";

contract Allocation is CoreContract, IExecutor, IHook {

    struct Config {
        uint maxPuppetList;
        uint transferOutGasLimit;
        uint callGasLimit;
    }

    Config public config;
    mapping(address => INpvReader) public venueReaders;
    uint256 constant EXEC_OFFSET = 100;

    mapping(bytes32 => uint) public totalAllocation;
    mapping(bytes32 => mapping(address => uint)) public allocationBalance;

    mapping(bytes32 => uint) public totalShares;
    mapping(bytes32 => uint) public accReturnPerShare;
    mapping(bytes32 => mapping(address => uint)) public userShares;
    mapping(bytes32 => mapping(address => uint)) public userReturnCheckpoint;

    mapping(bytes32 => IERC7579Account) public subaccountMap;
    mapping(bytes32 => uint) public subaccountRecordedBalance;
    mapping(IERC7579Account => IERC20[]) public masterCollateralList;

    mapping(bytes32 => INpvReader) public keyReader;
    mapping(address => bytes32[]) public openPositionKeys;
    mapping(address => mapping(bytes32 => uint)) public positionKeyIndex;

    mapping(bytes32 => uint) public pendingUtilization;

    constructor(IAuthority _authority, Config memory _config) CoreContract(_authority, abi.encode(_config)) {}

    function getConfig() external view returns (Config memory) {
        return config;
    }

    function getTotalNetPositionValue(bytes32 _key) public view returns (uint) {
        address _master = address(subaccountMap[_key]);
        if (_master == address(0)) return 0;

        bytes32[] memory _posKeys = openPositionKeys[_master];
        uint _total = 0;

        for (uint _i = 0; _i < _posKeys.length; ++_i) {
            bytes32 _posKey = _posKeys[_i];
            INpvReader _reader = keyReader[_posKey];
            if (address(_reader) == address(0)) continue;
            int256 _npv = _reader.getPositionNetValue(_posKey);
            if (_npv > 0) _total += uint(_npv);
        }

        return _total;
    }

    function getSharePrice(bytes32 _key) public view returns (uint) {
        if (totalShares[_key] == 0) return Precision.FLOAT_PRECISION;
        uint _npv = getTotalNetPositionValue(_key);
        if (_npv == 0) return Precision.FLOAT_PRECISION;
        return Precision.toFactor(_npv, totalShares[_key]);
    }

    function getUserValue(bytes32 _key, address _user) external view returns (uint) {
        uint _shares = userShares[_key][_user];
        uint _pending = pendingReturn(_key, _user);
        uint _shareValue = Precision.applyFactor(getSharePrice(_key), _shares);
        return _shareValue + _pending;
    }

    function pendingReturn(bytes32 _key, address _user) public view returns (uint) {
        uint _shares = userShares[_key][_user];
        uint _totalShares = totalShares[_key];
        if (_shares == 0 || _totalShares == 0) return 0;

        address _subaccount = address(subaccountMap[_key]);
        IERC20[] memory _tokens = masterCollateralList[IERC7579Account(_subaccount)];
        if (_tokens.length == 0) return 0;

        uint _balance = _tokens[0].balanceOf(_subaccount);
        uint _idle = totalAllocation[_key];
        uint _settledBalance = _balance > _idle ? _balance - _idle : 0;

        return Precision.applyFactor(Precision.toFactor(_shares, _totalShares), _settledBalance);
    }

    function allocate(
        IERC20 _collateralToken,
        address _masterAddr,
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
            revert Error.Allocation__ArrayLengthMismatch(_puppetCount, _allocationList.length);
        }

        bytes32 _key = PositionUtils.getMatchingKey(_collateralToken, _masterAddr);

        if (address(subaccountMap[_key]) == address(0)) {
            subaccountMap[_key] = _master;
            masterCollateralList[_master].push(_collateralToken);
        }

        uint _totalTransferred = 0;

        for (uint _i = 0; _i < _puppetCount; ++_i) {
            address _puppet = _puppetList[_i];
            uint _amount = _allocationList[_i];
            if (_amount == 0) continue;

            bytes memory _result = _executeFromExecutor(
                IERC7579Account(_puppet),
                address(_collateralToken),
                config.callGasLimit,
                abi.encodeCall(IERC20.transfer, (_masterAddr, _amount))
            );

            if (_result.length == 0 || !abi.decode(_result, (bool))) continue;

            allocationBalance[_key][_puppet] += _amount;
            _totalTransferred += _amount;
        }

        if (_totalTransferred == 0) revert Error.Allocation__ZeroAllocation();

        totalAllocation[_key] += _totalTransferred;
        subaccountRecordedBalance[_key] += _totalTransferred;

        _logEvent("Allocate", abi.encode(_key, _collateralToken, _master, _totalTransferred, totalAllocation[_key], _puppetList, _allocationList));
    }

    function utilize(
        IERC20 _collateralToken,
        address _masterAddr,
        address[] calldata _puppetList,
        uint[] calldata _utilizationList
    ) external auth {
        uint _puppetCount = _puppetList.length;
        if (_puppetCount != _utilizationList.length) revert Error.Allocation__ArrayLengthMismatch(_puppetCount, _utilizationList.length);

        bytes32 _key = PositionUtils.getMatchingKey(_collateralToken, _masterAddr);

        if (pendingUtilization[_key] > 0) revert Error.Allocation__InsufficientMasterAllocation(pendingUtilization[_key], 0);

        uint _totalShares = totalShares[_key];
        uint _cumulative = accReturnPerShare[_key];
        address _subaccount = address(subaccountMap[_key]);
        uint _actual = _collateralToken.balanceOf(_subaccount);
        uint _recorded = subaccountRecordedBalance[_key];
        if (_actual < _recorded) revert Error.Allocation__InsufficientMasterBalance(_actual, _recorded);
        uint _settled = _actual - _recorded;

        subaccountRecordedBalance[_key] = _actual;
        _cumulative += _totalShares > 0 ? Precision.toFactor(_settled, _totalShares) : 0;
        accReturnPerShare[_key] = _cumulative;

        uint _netPositionValue = getTotalNetPositionValue(_key);
        uint _sharePrice = Precision.toFactor(_netPositionValue, _totalShares);

        uint _totalUtilized = 0;
        uint _totalNewShares = 0;
        for (uint _i = 0; _i < _puppetCount; ++_i) {
            address _puppet = _puppetList[_i];
            uint _amount = _utilizationList[_i];
            if (_amount == 0) continue;

            uint _available = allocationBalance[_key][_puppet];
            if (_amount > _available) revert Error.Allocation__InsufficientBalance(_available, _amount);

            uint _newShares = Precision.toFactor(_amount, _sharePrice);
            uint _oldShares = userShares[_key][_puppet];

            userShares[_key][_puppet] = _oldShares + _newShares;

            if (_oldShares == 0) {
                userReturnCheckpoint[_key][_puppet] = _cumulative;
            } else {
                uint _oldCheckpoint = userReturnCheckpoint[_key][_puppet];
                userReturnCheckpoint[_key][_puppet] = (_oldShares * _oldCheckpoint + _newShares * _cumulative) / (_oldShares + _newShares);
            }

            allocationBalance[_key][_puppet] -= _amount;
            _totalUtilized += _amount;
            _totalNewShares += _newShares;
        }

        if (_totalUtilized == 0) revert Error.Allocation__ZeroAllocation();

        totalAllocation[_key] -= _totalUtilized;
        totalShares[_key] += _totalNewShares;
        pendingUtilization[_key] = _totalUtilized;

        _logEvent("Utilize", abi.encode(_key, _collateralToken, _masterAddr, _totalUtilized, _totalNewShares, _sharePrice, _puppetList, _utilizationList));
    }

    function withdrawAllocation(IERC20 _token, bytes32 _key, address _user, uint _amount) external auth {
        uint _available = allocationBalance[_key][_user];
        if (_amount > _available) revert Error.Allocation__InsufficientBalance(_available, _amount);

        allocationBalance[_key][_user] -= _amount;
        totalAllocation[_key] -= _amount;

        bytes memory _result = _executeFromExecutor(
            subaccountMap[_key], address(_token), config.transferOutGasLimit, abi.encodeCall(IERC20.transfer, (_user, _amount))
        );
        if (_result.length == 0 || !abi.decode(_result, (bool))) {
            revert Error.Allocation__TransferFailed();
        }
        subaccountRecordedBalance[_key] -= _amount;

        _logEvent("WithdrawAllocation", abi.encode(_key, _token, _user, _amount, allocationBalance[_key][_user]));
    }

    function masterDeposit(IERC20 _collateralToken, address _masterAddr, uint _amount) external auth {
        IERC7579Account _master = IERC7579Account(_masterAddr);

        bool _bothInstalled = _master.isModuleInstalled(MODULE_TYPE_EXECUTOR, address(this), "")
            && _master.isModuleInstalled(MODULE_TYPE_HOOK, address(this), "");
        if (!_bothInstalled) revert Error.Allocation__UnregisteredSubaccount();

        bytes32 _key = PositionUtils.getMatchingKey(_collateralToken, _masterAddr);

        if (address(subaccountMap[_key]) == address(0)) {
            subaccountMap[_key] = _master;
            masterCollateralList[_master].push(_collateralToken);
        }

        allocationBalance[_key][_masterAddr] += _amount;
        totalAllocation[_key] += _amount;
        subaccountRecordedBalance[_key] += _amount;

        _logEvent("MasterDeposit", abi.encode(_key, _collateralToken, _master, _amount, totalAllocation[_key]));
    }

    function withdraw(IERC20 _token, bytes32 _key, address _user, uint _amount) external auth {
        uint _shares = userShares[_key][_user];
        uint _totalShares = totalShares[_key];
        if (_shares == 0) revert Error.Allocation__InsufficientBalance(0, _amount);

        address _subaccount = address(subaccountMap[_key]);
        uint _balance = _token.balanceOf(_subaccount);
        uint _idle = totalAllocation[_key];
        uint _settledBalance = _balance > _idle ? _balance - _idle : 0;

        uint _claimable = Precision.applyFactor(Precision.toFactor(_shares, _totalShares), _settledBalance);
        if (_amount > _claimable) revert Error.Allocation__InsufficientBalance(_claimable, _amount);

        uint _sharesToBurn = Precision.applyFactor(Precision.toFactor(_amount, _claimable), _shares);
        userShares[_key][_user] -= _sharesToBurn;
        totalShares[_key] -= _sharesToBurn;

        if (_amount > 0) {
            bytes memory _result = _executeFromExecutor(
                subaccountMap[_key], address(_token), config.transferOutGasLimit, abi.encodeCall(IERC20.transfer, (_user, _amount))
            );

            if (_result.length == 0 || !abi.decode(_result, (bool))) revert Error.Allocation__TransferFailed();

            _logEvent("Withdraw", abi.encode(_key, _token, _user, _amount, _claimable, _sharesToBurn, _shares));
        }
    }

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
                uint _shares = totalShares[_key];
                uint _allocation = totalAllocation[_key];
                if (_shares > 0) revert Error.Allocation__ActiveShares(_shares);
                if (_allocation > 0) revert Error.Allocation__ActiveShares(_allocation);
            }
            delete masterCollateralList[_master];
        }
    }

    function preCheck(address, uint256, bytes calldata _msgData) external returns (bytes memory) {
        address _master = msg.sender;

        bytes4 _selector = bytes4(_msgData[0:4]);
        if (_selector == IERC7579Account.execute.selector ||
            _selector == IERC7579Account.executeFromExecutor.selector) {

            ModeCode _mode = ModeCode.wrap(bytes32(_msgData[4:36]));
            CallType _calltype = ModeLib.getCallType(_mode);

            uint256 _paramLen = uint256(bytes32(_msgData[EXEC_OFFSET - 32:EXEC_OFFSET]));
            bytes calldata _executionData = _msgData[EXEC_OFFSET:EXEC_OFFSET + _paramLen];

            if (_calltype == CALLTYPE_SINGLE) {
                (address _target,, bytes calldata _callData) = ExecutionLib.decodeSingle(_executionData);

                INpvReader _reader = venueReaders[_target];
                if (address(_reader) == address(0)) revert Error.VenueRegistry__ContractNotWhitelisted(_target);

                _trackPosition(_master, _callData, _reader);
            } else if (_calltype == CALLTYPE_BATCH) {
                Execution[] calldata _executions = ExecutionLib.decodeBatch(_executionData);
                for (uint256 _i = 0; _i < _executions.length; _i++) {
                    address _target = _executions[_i].target;

                    INpvReader _reader = venueReaders[_target];
                    if (address(_reader) == address(0)) revert Error.VenueRegistry__ContractNotWhitelisted(_target);

                    _trackPosition(_master, _executions[_i].callData, _reader);
                }
            } else if (_calltype == CALLTYPE_DELEGATECALL) {
                revert Error.Allocation__DelegateCallNotAllowed();
            } else {
                revert Error.Allocation__InvalidCallType();
            }

            IERC20[] memory _tokens = masterCollateralList[IERC7579Account(_master)];
            for (uint _i = 0; _i < _tokens.length; ++_i) {
                bytes32 _key = PositionUtils.getMatchingKey(_tokens[_i], _master);
                pendingUtilization[_key] = 0;
            }
        }

        return _msgData;
    }

    function postCheck(bytes calldata) external {}


    function _executeFromExecutor(IERC7579Account _from, address _to, uint _gas, bytes memory _data) internal returns (bytes memory) {
        ModeCode _mode = ModeLib.encode(CALLTYPE_SINGLE, EXECTYPE_TRY, MODE_DEFAULT, ModePayload.wrap(0x00));
        try _from.executeFromExecutor{gas: _gas}(_mode, ExecutionLib.encodeSingle(_to, 0, _data)) returns (bytes[] memory _results) {
            return _results[0];
        } catch {
            return "";
        }
    }

    function _setConfig(bytes memory _data) internal override {
        Config memory _config = abi.decode(_data, (Config));
        if (_config.maxPuppetList == 0) revert("Invalid max puppet list");
        if (_config.transferOutGasLimit == 0) revert("Invalid transfer out gas limit");
        if (_config.callGasLimit == 0) revert("Invalid call gas limit");
        config = _config;
    }

    function setVenueReader(address _venue, INpvReader _reader) external auth {
        venueReaders[_venue] = _reader;
        _logEvent("SetVenueReader", abi.encode(_venue, _reader));
    }

    function _trackPosition(address _master, bytes calldata _callData, INpvReader _reader) internal {
        bytes32 _posKey = _reader.parsePositionKey(_master, _callData);
        if (_posKey == bytes32(0)) return;

        if (positionKeyIndex[_master][_posKey] == 0) {
            openPositionKeys[_master].push(_posKey);
            positionKeyIndex[_master][_posKey] = openPositionKeys[_master].length;
            keyReader[_posKey] = _reader;
        }
    }

}
