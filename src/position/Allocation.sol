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

    // ERC-7579 calldata offset for execute functions
    uint256 constant EXEC_OFFSET = 100;

    // Balance tracking
    mapping(bytes32 => mapping(address => uint)) public allocationBalance;
    mapping(bytes32 => uint) public totalAllocation;

    // Share-based distribution (priced at NPV for fair distribution)
    mapping(bytes32 => mapping(address => uint)) public userShares;
    mapping(bytes32 => uint) public totalShares;
    mapping(bytes32 => uint) public cumulativeSettlementPerShare;
    mapping(bytes32 => mapping(address => uint)) public userShareCheckpoint;
    mapping(bytes32 => uint) public pendingUtilization;

    mapping(bytes32 => IERC7579Account) public subaccountMap;
    mapping(bytes32 => uint) public subaccountRecordedBalance;
    mapping(IERC7579Account => IERC20[]) public masterCollateralList;

    // Position tracking
    mapping(bytes32 => INpvReader) public keyReader;
    mapping(address => bytes32[]) public openPositionKeys;
    mapping(address => mapping(bytes32 => uint)) public positionKeyIndex;

    constructor(IAuthority _authority, Config memory _config) CoreContract(_authority, abi.encode(_config)) {}

    // ===================== Views =====================

    function getConfig() external view returns (Config memory) {
        return config;
    }

    function getTotalNPV(bytes32 _key) public view returns (uint) {
        address _master = address(subaccountMap[_key]);
        if (_master == address(0)) return 0;

        INpvReader _reader = keyReader[_key];
        if (address(_reader) == address(0)) return 0;

        bytes32[] memory _posKeys = openPositionKeys[_master];
        uint _total = 0;
        for (uint _i = 0; _i < _posKeys.length; ++_i) {
            int256 _npv = _reader.getPositionNetValue(_posKeys[_i]);
            if (_npv > 0) _total += uint(_npv);
        }
        return _total;
    }

    function getSharePrice(bytes32 _key) public view returns (uint) {
        if (totalShares[_key] == 0) return Precision.FLOAT_PRECISION;
        uint _npv = getTotalNPV(_key);
        if (_npv == 0) return Precision.FLOAT_PRECISION;
        return Precision.toFactor(_npv, totalShares[_key]);
    }

    function getUserValue(bytes32 _key, address _user) external view returns (uint) {
        uint _shares = userShares[_key][_user];
        uint _pending = pendingSettlement(_key, _user);
        uint _allocation = allocationBalance[_key][_user];

        uint _shareValue = Precision.applyFactor(getSharePrice(_key), _shares);
        return _allocation + _shareValue + _pending;
    }

    function pendingSettlement(bytes32 _key, address _user) public view returns (uint) {
        uint _shares = userShares[_key][_user];
        if (_shares == 0) return 0;

        uint _checkpoint = userShareCheckpoint[_key][_user];
        uint _cumulative = cumulativeSettlementPerShare[_key];
        if (_cumulative <= _checkpoint) return 0;

        return Precision.applyFactor(_cumulative - _checkpoint, _shares);
    }

    // ===================== External =====================

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
        _settle(_key, _collateralToken);

        if (address(subaccountMap[_key]) == address(0)) {
            subaccountMap[_key] = _master;
            masterCollateralList[_master].push(_collateralToken);
        }

        uint _allocated = 0;
        uint[] memory _puppetShareList = new uint[](_puppetCount);
        uint _cumulative = cumulativeSettlementPerShare[_key];

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

            _puppetShareList[_i] = userShares[_key][_puppet];
            userShareCheckpoint[_key][_puppet] = _cumulative;

            allocationBalance[_key][_puppet] += _amount;
            _allocated += _amount;
        }

        if (_allocated == 0) revert Error.Allocation__ZeroAllocation();

        totalAllocation[_key] += _allocated;
        subaccountRecordedBalance[_key] += _allocated;

        _logEvent("Allocate", abi.encode(_key, _collateralToken, _master, _allocated, _puppetList, _allocationList, _puppetShareList));
    }

    function masterDeposit(IERC20 _collateralToken, address _masterAddr, uint _amount) external auth {
        IERC7579Account _master = IERC7579Account(_masterAddr);

        bool _bothInstalled = _master.isModuleInstalled(MODULE_TYPE_EXECUTOR, address(this), "")
            && _master.isModuleInstalled(MODULE_TYPE_HOOK, address(this), "");
        if (!_bothInstalled) revert Error.Allocation__UnregisteredSubaccount();

        bytes32 _key = PositionUtils.getMatchingKey(_collateralToken, _masterAddr);
        _settle(_key, _collateralToken);

        if (address(subaccountMap[_key]) == address(0)) {
            subaccountMap[_key] = _master;
            masterCollateralList[_master].push(_collateralToken);
        }

        uint _shares = userShares[_key][_masterAddr];
        userShareCheckpoint[_key][_masterAddr] = cumulativeSettlementPerShare[_key];

        uint _allocation = allocationBalance[_key][_masterAddr] += _amount;

        totalAllocation[_key] += _amount;
        subaccountRecordedBalance[_key] += _amount;

        _logEvent("MasterDeposit", abi.encode(_key, _collateralToken, _master, _amount, _shares, _allocation));
    }

    function withdraw(IERC20 _token, bytes32 _key, address _user, uint _amount) external auth {
        uint _cumulative = _settle(_key, _token);
        uint _allocation = allocationBalance[_key][_user];
        uint _shares = userShares[_key][_user];
        uint _realized = 0;

        // Realize share settlement
        if (_shares > 0) {
            uint _checkpoint = userShareCheckpoint[_key][_user];
            if (_cumulative <= _checkpoint) revert Error.Allocation__SharesNotSettled(_shares);

            _realized = Precision.applyFactor(_cumulative - _checkpoint, _shares);
            totalShares[_key] -= _shares;
            _allocation += _realized;
            userShares[_key][_user] = 0;
        }

        if (_amount > 0) {
            if (_allocation < _amount) revert Error.Allocation__InsufficientAllocation(_allocation, _amount);
            _allocation -= _amount;
            totalAllocation[_key] -= _amount;
        }

        allocationBalance[_key][_user] = _allocation;
        userShareCheckpoint[_key][_user] = _cumulative;

        if (_amount > 0) {
            bytes memory _result = _executeFromExecutor(
                subaccountMap[_key], address(_token), config.transferOutGasLimit, abi.encodeCall(IERC20.transfer, (_user, _amount))
            );
            if (_result.length == 0 || !abi.decode(_result, (bool))) {
                revert Error.Allocation__TransferFailed();
            }
            subaccountRecordedBalance[_key] -= _amount;

            _logEvent("Withdraw", abi.encode(_key, _token, _user, _amount, _realized, _shares, _allocation));
        }
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
                uint _shares = totalShares[_key];
                if (_shares > 0) revert Error.Allocation__ActiveShares(_shares);
            }
            delete masterCollateralList[_master];
        }
    }

    /**
     * @notice Pre-execution hook - settles balances, validates targets, and tracks positions
     * @dev Only validates direct targets from the smart account's execute call.
     *      Inner calls by whitelisted contracts (e.g., GMX ExchangeRouter -> OrderHandler)
     *      don't pass through this hook and work normally.
     */
    function preCheck(address, uint256, bytes calldata _msgData) external returns (bytes memory) {
        IERC7579Account _subaccount = IERC7579Account(msg.sender);
        address _master = address(_subaccount);
        IERC20[] memory _tokens = masterCollateralList[_subaccount];

        // Settle all registered collateral tokens before any execution
        for (uint _i = 0; _i < _tokens.length; ++_i) {
            IERC20 _token = _tokens[_i];
            _settle(PositionUtils.getMatchingKey(_token, _master), _token);
        }

        // Validate execution targets against whitelist
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

                _trackPosition(_master, _callData, _reader, _tokens);
            } else if (_calltype == CALLTYPE_BATCH) {
                Execution[] calldata _executions = ExecutionLib.decodeBatch(_executionData);
                for (uint256 _i = 0; _i < _executions.length; _i++) {
                    address _target = _executions[_i].target;

                    INpvReader _reader = venueReaders[_target];
                    if (address(_reader) == address(0)) revert Error.VenueRegistry__ContractNotWhitelisted(_target);

                    _trackPosition(_master, _executions[_i].callData, _reader, _tokens);
                }
            } else if (_calltype == CALLTYPE_DELEGATECALL) {
                revert Error.Allocation__DelegateCallNotAllowed();
            } else {
                revert Error.Allocation__InvalidCallType();
            }
        }

        return _msgData;
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

            pendingUtilization[_key] += _utilized;
            totalAllocation[_key] -= _utilized;
            subaccountRecordedBalance[_key] = _actual;

            _logEvent("Action", abi.encode(_key, _token, _subaccount, _utilized, pendingUtilization[_key], _hookData));
        }
    }

    /// @notice Distribute pending utilization to users as shares priced at current NPV
    /// @dev Called after postCheck to convert pending utilization into shares
    function distributeShares(bytes32 _key, address[] calldata _users) external auth {
        uint _pending = pendingUtilization[_key];
        if (_pending == 0) return;

        uint _sharePrice = getSharePrice(_key);
        uint _cumulative = cumulativeSettlementPerShare[_key];

        uint _totalAlloc = 0;
        uint[] memory _allocations = new uint[](_users.length);

        for (uint _i = 0; _i < _users.length; ++_i) {
            _allocations[_i] = allocationBalance[_key][_users[_i]];
            _totalAlloc += _allocations[_i];
        }

        if (_totalAlloc == 0) return;

        uint _totalNewShares = 0;
        for (uint _i = 0; _i < _users.length; ++_i) {
            if (_allocations[_i] == 0) continue;

            // User's portion of pending utilization based on their allocation
            uint _userPortion = Precision.applyFactor(
                Precision.toFactor(_allocations[_i], _totalAlloc),
                _pending
            );

            // Cap at available allocation
            if (_userPortion > _allocations[_i]) _userPortion = _allocations[_i];

            // Convert to shares at current NPV price
            uint _newShares = Precision.toFactor(_userPortion, _sharePrice);

            userShares[_key][_users[_i]] += _newShares;
            userShareCheckpoint[_key][_users[_i]] = _cumulative;
            allocationBalance[_key][_users[_i]] -= _userPortion;
            _totalNewShares += _newShares;
        }

        totalShares[_key] += _totalNewShares;
        pendingUtilization[_key] = 0;

        _logEvent("DistributeShares", abi.encode(_key, _users, _pending, _sharePrice, _totalNewShares));
    }

    // ===================== Internal =====================

    function _executeFromExecutor(IERC7579Account _from, address _to, bytes memory _data) internal returns (bytes memory) {
        ModeCode _mode = ModeLib.encode(CALLTYPE_SINGLE, EXECTYPE_TRY, MODE_DEFAULT, ModePayload.wrap(0x00));
        return _from.executeFromExecutor(_mode, ExecutionLib.encodeSingle(_to, 0, _data))[0];
    }

    function _executeFromExecutor(IERC7579Account _from, address _to, uint _gas, bytes memory _data) internal returns (bytes memory) {
        ModeCode _mode = ModeLib.encode(CALLTYPE_SINGLE, EXECTYPE_TRY, MODE_DEFAULT, ModePayload.wrap(0x00));
        try _from.executeFromExecutor{gas: _gas}(_mode, ExecutionLib.encodeSingle(_to, 0, _data)) returns (bytes[] memory _results) {
            return _results[0];
        } catch {
            return "";
        }
    }

    function _settle(bytes32 _key, IERC20 _token) internal returns (uint _cumulative) {
        uint _totalShares = totalShares[_key];
        _cumulative = cumulativeSettlementPerShare[_key];
        if (_totalShares == 0) return _cumulative;

        address _subaccount = address(subaccountMap[_key]);
        uint _actual = _token.balanceOf(_subaccount);
        uint _recorded = subaccountRecordedBalance[_key];
        if (_actual <= _recorded) return _cumulative;

        uint _settled = _actual - _recorded;
        subaccountRecordedBalance[_key] = _actual;
        _cumulative += Precision.toFactor(_settled, _totalShares);
        cumulativeSettlementPerShare[_key] = _cumulative;

        _logEvent("Settle", abi.encode(_key, _token, _subaccount, _settled, _totalShares, _cumulative));
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

    function _trackPosition(address _master, bytes calldata _callData, INpvReader _reader, IERC20[] memory _tokens) internal {
        bytes32 _posKey = _reader.parsePositionKey(_master, _callData);
        if (_posKey == bytes32(0)) return;

        if (positionKeyIndex[_master][_posKey] == 0) {
            openPositionKeys[_master].push(_posKey);
            positionKeyIndex[_master][_posKey] = openPositionKeys[_master].length;

            // Set reader for all collateral keys if not set
            for (uint _i = 0; _i < _tokens.length; ++_i) {
                bytes32 _key = PositionUtils.getMatchingKey(_tokens[_i], _master);
                if (address(keyReader[_key]) == address(0)) {
                    keyReader[_key] = _reader;
                }
            }
        }
    }

    function _cleanupPositions(address _master, INpvReader _reader) internal {
        bytes32[] storage _keys = openPositionKeys[_master];
        uint256 _i = 0;

        while (_i < _keys.length) {
            bytes32 _posKey = _keys[_i];

            // Remove if position value is 0 (closed or non-existent)
            if (_reader.getPositionNetValue(_posKey) == 0) {
                // Swap with last and pop
                uint256 _lastIdx = _keys.length - 1;
                if (_i != _lastIdx) {
                    bytes32 _lastKey = _keys[_lastIdx];
                    _keys[_i] = _lastKey;
                    positionKeyIndex[_master][_lastKey] = _i + 1;
                }
                _keys.pop();
                delete positionKeyIndex[_master][_posKey];
            } else {
                _i++;
            }
        }
    }
}
