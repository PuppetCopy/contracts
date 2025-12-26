// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC7579Account} from "erc7579/interfaces/IERC7579Account.sol";
import {IExecutor, IHook, MODULE_TYPE_EXECUTOR, MODULE_TYPE_HOOK} from "erc7579/interfaces/IERC7579Module.sol";
import {ModeLib, ModeCode, ModePayload, CallType, CALLTYPE_SINGLE, CALLTYPE_BATCH, CALLTYPE_DELEGATECALL, EXECTYPE_TRY, MODE_DEFAULT} from "erc7579/lib/ModeLib.sol";
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
    mapping(bytes32 => uint) public totalUtilization;

    // Direct utilization tracking per user
    mapping(bytes32 => mapping(address => uint)) public userUtilization;

    // Settlement distribution (cumulative per utilization)
    mapping(bytes32 => uint) public cumulativeSettlementPerUtilization;
    mapping(bytes32 => mapping(address => uint)) public userSettlementCheckpoint;

    // Subaccount registry
    mapping(bytes32 => IERC7579Account) public subaccountMap;
    mapping(bytes32 => uint) public subaccountRecordedBalance;
    mapping(IERC7579Account => IERC20[]) public masterCollateralList;

    // Open position tracking (subaccount => position keys)
    mapping(address => bytes32[]) public openPositionKeys;
    mapping(address => mapping(bytes32 => uint)) public positionKeyIndex; // 1-indexed for existence check

    constructor(IAuthority _authority, Config memory _config) CoreContract(_authority, abi.encode(_config)) {}

    // ===================== Views =====================

    function getConfig() external view returns (Config memory) {
        return config;
    }

    function getUtilization(bytes32 _key, address _user) public view returns (uint) {
        return userUtilization[_key][_user];
    }

    function getAllocation(bytes32 _key, address _user) external view returns (uint) {
        uint _allocation = allocationBalance[_key][_user];
        uint _utilized = getUtilization(_key, _user);
        return _utilized >= _allocation ? 0 : _allocation - _utilized;
    }

    function pendingSettlement(bytes32 _key, address _user) external view returns (uint) {
        uint _util = getUtilization(_key, _user);
        if (_util == 0) return 0;

        uint _checkpoint = userSettlementCheckpoint[_key][_user];
        uint _cumulative = cumulativeSettlementPerUtilization[_key];
        if (_cumulative <= _checkpoint) return 0;

        return Precision.applyFactor(_cumulative - _checkpoint, _util);
    }

    function getOpenPositions(address _subaccount) external view returns (bytes32[] memory) {
        return openPositionKeys[_subaccount];
    }

    function hasOpenPosition(address _subaccount, bytes32 _positionKey) external view returns (bool) {
        return positionKeyIndex[_subaccount][_positionKey] > 0;
    }

    /// @notice Get net value of a position for a specific venue target
    /// @param _venue The venue contract address (e.g., GMX ExchangeRouter)
    /// @param _positionKey The position key
    /// @return netValue Position net value (collateral + PnL - fees)
    function getPositionNetValue(address _venue, bytes32 _positionKey) external view returns (int256) {
        INpvReader _reader = venueReaders[_venue];
        if (address(_reader) == address(0)) revert Error.VenueRegistry__ContractNotWhitelisted(_venue);
        return _reader.getPositionNetValue(_positionKey);
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
        uint[] memory _puppetUtilList = new uint[](_puppetCount);
        uint _settleCumulative = cumulativeSettlementPerUtilization[_key];

        for (uint _i = 0; _i < _puppetCount; ++_i) {
            address _puppet = _puppetList[_i];
            uint _amount = _allocationList[_i];
            if (_amount == 0) continue;

            // Call executeFromExecutor directly on puppet (Allocation is puppet's executor)
            bytes memory _result = _executeFromExecutor(
                IERC7579Account(_puppet),
                address(_collateralToken),
                config.callGasLimit,
                abi.encodeCall(IERC20.transfer, (_masterAddr, _amount))
            );

            // EXECTYPE_TRY returns empty bytes on failure, actual result on success
            if (_result.length == 0 || !abi.decode(_result, (bool))) continue;

            // Record current utilization and sync settlement checkpoint
            _puppetUtilList[_i] = userUtilization[_key][_puppet];
            userSettlementCheckpoint[_key][_puppet] = _settleCumulative;

            allocationBalance[_key][_puppet] += _amount;
            _allocated += _amount;
        }

        if (_allocated == 0) revert Error.Allocation__ZeroAllocation();

        totalAllocation[_key] += _allocated;
        subaccountRecordedBalance[_key] += _allocated;

        _logEvent("Allocate", abi.encode(_key, _collateralToken, _master, _allocated, _puppetList, _allocationList, _puppetUtilList));
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

        // Record current utilization and sync settlement checkpoint
        uint _util = userUtilization[_key][_masterAddr];
        userSettlementCheckpoint[_key][_masterAddr] = cumulativeSettlementPerUtilization[_key];

        uint _allocation = allocationBalance[_key][_masterAddr] += _amount;

        totalAllocation[_key] += _amount;
        subaccountRecordedBalance[_key] += _amount;

        _logEvent("MasterDeposit", abi.encode(_key, _collateralToken, _master, _amount, _util, _allocation));
    }

    function withdraw(IERC20 _token, bytes32 _key, address _user, uint _amount) external auth {
        uint _settleCumulative = _settle(_key, _token);
        uint _allocation = allocationBalance[_key][_user];
        uint _util = userUtilization[_key][_user];
        uint _realized = 0;

        // Realize utilization settlement
        if (_util > 0) {
            uint _checkpoint = userSettlementCheckpoint[_key][_user];
            if (_settleCumulative <= _checkpoint) revert Error.Allocation__UtilizationNotSettled(_util);

            _realized = Precision.applyFactor(_settleCumulative - _checkpoint, _util);
            totalUtilization[_key] -= _util;
            totalAllocation[_key] += _realized;
            _allocation = _allocation + _realized - _util;
            userUtilization[_key][_user] = 0;
        }

        if (_amount > 0) {
            if (_allocation < _amount) revert Error.Allocation__InsufficientAllocation(_allocation, _amount);
            _allocation -= _amount;
            totalAllocation[_key] -= _amount;
        }

        allocationBalance[_key][_user] = _allocation;
        userSettlementCheckpoint[_key][_user] = _settleCumulative;

        if (_amount > 0) {
            bytes memory _result = _executeFromExecutor(
                subaccountMap[_key], address(_token), config.transferOutGasLimit, abi.encodeCall(IERC20.transfer, (_user, _amount))
            );
            if (_result.length == 0 || !abi.decode(_result, (bool))) {
                revert Error.Allocation__TransferFailed();
            }
            subaccountRecordedBalance[_key] -= _amount;

            _logEvent("Withdraw", abi.encode(_key, _token, _user, _amount, _realized, _util, _allocation));
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
                uint _utilized = totalUtilization[_key];
                if (_utilized > 0) revert Error.Allocation__ActiveUtilization(_utilized);
            }
            delete masterCollateralList[_master];
            // TODO: clear subaccountMap entries for each _key
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
            uint _totalAlloc = totalAllocation[_key];

            // Update globals
            uint _newTotalUtil = totalUtilization[_key] + _utilized;
            uint _allocated = _totalAlloc - _utilized;
            totalUtilization[_key] = _newTotalUtil;
            totalAllocation[_key] = _allocated;
            subaccountRecordedBalance[_key] = _actual;

            _logEvent("Action", abi.encode(_key, _token, _subaccount, _utilized, _newTotalUtil, _allocated, _hookData));
        }
    }

    /// @notice Distribute utilization to a specific user
    /// @dev Called externally after utilization to update individual user state
    function distributeUtilization(bytes32 _key, address _user, uint _amount) external auth {
        uint _allocation = allocationBalance[_key][_user];
        uint _currentUtil = userUtilization[_key][_user];
        uint _available = _allocation - _currentUtil;

        // Cap utilization at available allocation
        uint _toUtilize = _amount > _available ? _available : _amount;
        if (_toUtilize == 0) return;

        userUtilization[_key][_user] = _currentUtil + _toUtilize;
        allocationBalance[_key][_user] = _allocation - _toUtilize;
    }

    /// @notice Batch distribute utilization to multiple users proportionally
    /// @dev Called after postCheck to attribute utilization to specific users
    function distributeUtilizationBatch(
        bytes32 _key,
        address[] calldata _users,
        uint _totalUtilized
    ) external auth {
        uint _totalAlloc = 0;
        uint[] memory _allocations = new uint[](_users.length);

        // Calculate total allocation of provided users
        for (uint _i = 0; _i < _users.length; ++_i) {
            uint _alloc = allocationBalance[_key][_users[_i]];
            uint _util = userUtilization[_key][_users[_i]];
            _allocations[_i] = _alloc - _util; // Available allocation
            _totalAlloc += _allocations[_i];
        }

        if (_totalAlloc == 0) return;

        // Distribute proportionally
        uint _distributed = 0;
        for (uint _i = 0; _i < _users.length; ++_i) {
            if (_allocations[_i] == 0) continue;

            uint _share = Precision.applyFactor(
                Precision.toFactor(_allocations[_i], _totalAlloc),
                _totalUtilized
            );

            // Cap at available
            if (_share > _allocations[_i]) _share = _allocations[_i];

            userUtilization[_key][_users[_i]] += _share;
            allocationBalance[_key][_users[_i]] -= _share;
            _distributed += _share;
        }
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

    function _setConfig(bytes memory _data) internal override {
        Config memory _config = abi.decode(_data, (Config));
        if (_config.maxPuppetList == 0) revert("Invalid max puppet list");
        if (_config.transferOutGasLimit == 0) revert("Invalid transfer out gas limit");
        if (_config.callGasLimit == 0) revert("Invalid call gas limit");
        config = _config;
    }

    /// @notice Set venue readers (batch)
    function setVenueReaders(address[] calldata _venues, INpvReader _reader) external auth {
        for (uint256 i = 0; i < _venues.length; i++) {
            venueReaders[_venues[i]] = _reader;
        }
        _logEvent("SetVenueReaders", abi.encode(_venues, address(_reader)));
    }

    function _trackPosition(address _master, bytes calldata _callData, INpvReader _reader) internal {
        bytes32 _posKey = _reader.parsePositionKey(_master, _callData);
        if (_posKey == bytes32(0)) return;

        if (positionKeyIndex[_master][_posKey] == 0) {
            openPositionKeys[_master].push(_posKey);
            positionKeyIndex[_master][_posKey] = openPositionKeys[_master].length;
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
