// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.31;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {CoreContract} from "../utils/CoreContract.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {IERC7579Account} from "erc7579/interfaces/IERC7579Account.sol";
import {IExecutor, IHook, MODULE_TYPE_EXECUTOR, MODULE_TYPE_HOOK} from "erc7579/interfaces/IERC7579Module.sol";
import {ModeLib, ModeCode, CallType, ExecType, ModeSelector, ModePayload, CALLTYPE_SINGLE, EXECTYPE_TRY, MODE_DEFAULT} from "erc7579/lib/ModeLib.sol";
import {ExecutionLib} from "erc7579/lib/ExecutionLib.sol";
import {Error} from "./../utils/Error.sol";
import {PositionUtils} from "./utils/PositionUtils.sol";

/**
 * @title Allocation
 * @notice Coordinates allocations between puppet and trader accounts
 * @dev Acts as session owner on puppet accounts to execute transfers
 *
 * Flow:
 * 1. Puppet installs Smart Sessions with Allocation as session owner
 * 2. Puppet configures policies (AllowedRecipient, AllowanceRate, Throttle)
 * 3. Trader (7579 account) calls allocate() to gather funds
 * 4. Allocation executes transfers from puppets → trader via Smart Sessions
 * 5. Smart Sessions validates each transfer against puppet's policies
 * 6. Allocation records accounting for settlement distribution
 */
contract Allocation is CoreContract, IExecutor, IHook {
    using SafeERC20 for IERC20;

    struct Config {
        uint maxPuppetList;
    }

    Config public config;

    // ============ Allocation Tracking ============

    mapping(bytes32 traderMatchingKey => mapping(address user => uint)) public allocationBalance;
    mapping(bytes32 traderMatchingKey => uint) public totalAllocation;
    mapping(bytes32 traderMatchingKey => uint) public totalUtilization;

    // Epoch tracking for lazy utilization calculation
    mapping(bytes32 traderMatchingKey => uint) public currentEpoch;
    mapping(bytes32 traderMatchingKey => mapping(uint epoch => uint)) public epochRemaining;
    mapping(bytes32 traderMatchingKey => mapping(address user => uint)) public userEpoch;
    mapping(bytes32 traderMatchingKey => mapping(address user => uint)) public userRemainingCheckpoint;
    mapping(bytes32 traderMatchingKey => mapping(address user => uint)) public userAllocationSnapshot;

    // Settlement tracking
    mapping(bytes32 traderMatchingKey => uint) public cumulativeSettlementPerUtilization;
    mapping(bytes32 traderMatchingKey => mapping(address user => uint)) public userSettlementCheckpoint;

    // Trader subaccount tracking
    mapping(bytes32 traderMatchingKey => IERC7579Account) public subaccountMap;
    mapping(bytes32 traderMatchingKey => uint) public subaccountRecordedBalance;
    mapping(IERC7579Account subaccount => address trader) public subaccountTraderMap;
    mapping(IERC7579Account subaccount => IERC20[]) internal _subaccountTokenList;
    mapping(IERC7579Account subaccount => bool) public registeredSubaccount;

    uint constant PRECISION = 1e30;

    constructor(IAuthority _authority, Config memory _config) CoreContract(_authority, abi.encode(_config)) {}

    function getConfig() external view returns (Config memory) {
        return config;
    }

    function getSubaccountTokenList(IERC7579Account _subaccount) external view returns (IERC20[] memory) {
        return _subaccountTokenList[_subaccount];
    }

    // ============ ERC-7579 Executor Module Interface ============

    /**
     * @notice Called when this module is installed on a smart account
     * @dev Only registers when BOTH executor and hook are installed.
     *      onInstall is called AFTER the module is marked as installed.
     */
    function onInstall(bytes calldata) external {
        IERC7579Account _trader = IERC7579Account(msg.sender);

        bool executorInstalled = _trader.isModuleInstalled(MODULE_TYPE_EXECUTOR, address(this), "");
        bool hookInstalled = _trader.isModuleInstalled(MODULE_TYPE_HOOK, address(this), "");

        // Only register when BOTH are installed (second install completes setup)
        if (executorInstalled && hookInstalled) {
            registeredSubaccount[_trader] = true;
        }
    }

    /**
     * @notice Called when this module is uninstalled from a smart account
     * @dev Unregisters on first uninstall (when both still show as installed).
     *      onUninstall is called BEFORE the module is marked as uninstalled.
     *      Can only uninstall when all positions are settled (no active utilization).
     */
    function onUninstall(bytes calldata) external {
        IERC7579Account _trader = IERC7579Account(msg.sender);

        bool executorInstalled = _trader.isModuleInstalled(MODULE_TYPE_EXECUTOR, address(this), "");
        bool hookInstalled = _trader.isModuleInstalled(MODULE_TYPE_HOOK, address(this), "");

        // First uninstall - both still show installed (about to be cleared after this call)
        if (executorInstalled && hookInstalled) {
            // Check all token positions are fully settled
            IERC20[] memory _tokens = _subaccountTokenList[_trader];
            for (uint _i = 0; _i < _tokens.length; ++_i) {
                bytes32 _traderMatchingKey =
                    PositionUtils.getTraderMatchingKey(_tokens[_i], subaccountTraderMap[_trader]);
                uint _utilization = totalUtilization[_traderMatchingKey];
                if (_utilization > 0) {
                    revert Error.Allocation__ActiveUtilization(_utilization);
                }
            }

            delete registeredSubaccount[_trader];
        }
        // Second uninstall - already unregistered, no-op
    }

    function isModuleType(uint256 moduleTypeId) external pure returns (bool) {
        return moduleTypeId == MODULE_TYPE_EXECUTOR || moduleTypeId == MODULE_TYPE_HOOK;
    }

    function isInitialized(address _smartAccount) external view returns (bool) {
        return registeredSubaccount[IERC7579Account(_smartAccount)];
    }

    // ============ IHook ============

    /**
     * @notice Pre-execution hook - syncs any pending settlements before trade
     * @dev Called by smart account before executing a transaction
     */
    function preCheck(address, uint256, bytes calldata callData) external returns (bytes memory) {
        IERC7579Account _subaccount = IERC7579Account(msg.sender);
        if (!registeredSubaccount[_subaccount]) revert Error.Allocation__UnregisteredSubaccount();
        _syncSettlement(_subaccount);
        return callData; // Pass execution calldata through to postCheck
    }

    /**
     * @notice Post-execution hook - syncs utilization after trade
     * @dev Called by smart account after executing a transaction
     */
    function postCheck(bytes calldata hookData) external {
        IERC7579Account _subaccount = IERC7579Account(msg.sender);
        if (!registeredSubaccount[_subaccount]) revert Error.Allocation__UnregisteredSubaccount();
        _syncUtilization(_subaccount, hookData);
    }

    // ============ View Functions ============

    function getUserUtilization(bytes32 _traderMatchingKey, address _user) public view returns (uint) {
        uint _snapshot = userAllocationSnapshot[_traderMatchingKey][_user];
        if (_snapshot == 0) return 0;

        uint _userEpoch = userEpoch[_traderMatchingKey][_user];
        uint _currentEpoch = currentEpoch[_traderMatchingKey];

        if (_userEpoch < _currentEpoch) return _snapshot;

        uint _checkpoint = userRemainingCheckpoint[_traderMatchingKey][_user];
        uint _current = epochRemaining[_traderMatchingKey][_currentEpoch];

        if (_current >= _checkpoint) return 0;

        return (_snapshot * (_checkpoint - _current)) / _checkpoint;
    }

    function getAvailableAllocation(bytes32 _traderMatchingKey, address _user) external view returns (uint) {
        uint _allocation = allocationBalance[_traderMatchingKey][_user];
        uint _utilization = getUserUtilization(_traderMatchingKey, _user);

        if (_utilization >= _allocation) return 0;
        return _allocation - _utilization;
    }

    function pendingSettlement(bytes32 _traderMatchingKey, address _user) external view returns (uint) {
        return pendingSettlement(_traderMatchingKey, _user, getUserUtilization(_traderMatchingKey, _user));
    }

    function pendingSettlement(bytes32 _traderMatchingKey, address _user, uint _utilization)
        public
        view
        returns (uint)
    {
        if (_utilization == 0) return 0;

        uint _cumulative = cumulativeSettlementPerUtilization[_traderMatchingKey];
        uint _lastCheckpoint = userSettlementCheckpoint[_traderMatchingKey][_user];

        if (_cumulative <= _lastCheckpoint) return 0;

        return (_utilization * (_cumulative - _lastCheckpoint)) / PRECISION;
    }

    // ============ Allocation ============

    /**
     * @notice Trader gathers allocations from puppets
     * @dev Executes transfers from puppet accounts via Smart Sessions.
     *      Allocation contract must be session owner on puppet accounts.
     *      Puppet policies validate each transfer (recipient, amount, throttle).
     * @param _collateralToken The collateral token
     * @param _trader The trader's 7579 account (receives funds)
     * @param _traderAllocation Trader's own allocation amount (already in trader account)
     * @param _puppetList List of puppet accounts to pull from
     * @param _allocationList Allocation amounts per puppet
     */
    function allocate(
        IERC20 _collateralToken,
        IERC7579Account _trader,
        uint _traderAllocation,
        address[] calldata _puppetList,
        uint[] calldata _allocationList
    ) external auth {
        if (!registeredSubaccount[_trader]) revert Error.Allocation__UnregisteredSubaccount();

        uint _puppetCount = _puppetList.length;
        if (_puppetCount > config.maxPuppetList) {
            revert Error.Allocation__PuppetListTooLarge(_puppetCount, config.maxPuppetList);
        }
        if (_puppetCount != _allocationList.length) {
            revert Error.Allocation__PuppetListTooLarge(_puppetCount, _allocationList.length);
        }

        address _traderAddr = address(_trader);
        bytes32 _traderMatchingKey = PositionUtils.getTraderMatchingKey(_collateralToken, _traderAddr);

        // Initialize epoch if needed
        uint _epoch = currentEpoch[_traderMatchingKey];
        if (epochRemaining[_traderMatchingKey][_epoch] == 0) {
            bool _firstInit = _epoch == 0 && totalUtilization[_traderMatchingKey] == 0
                && totalAllocation[_traderMatchingKey] == 0;

            if (_firstInit) {
                epochRemaining[_traderMatchingKey][0] = PRECISION;
            } else {
                ++_epoch;
                currentEpoch[_traderMatchingKey] = _epoch;
                epochRemaining[_traderMatchingKey][_epoch] = PRECISION;
            }
        }

        // Register trader mapping if first allocation
        if (subaccountMap[_traderMatchingKey] == IERC7579Account(address(0))) {
            subaccountMap[_traderMatchingKey] = _trader;
            subaccountTraderMap[_trader] = _traderAddr;
            _subaccountTokenList[_trader].push(_collateralToken);
        }

        uint _puppetTotalAllocation = 0;
        uint[] memory _puppetUtilizationList = new uint[](_puppetCount);

        // Execute transfers from each puppet via trader's account
        // Trader executes on puppet accounts so policies see trader as actor
        for (uint _i = 0; _i < _puppetCount; ++_i) {
            address _puppet = _puppetList[_i];
            uint _amount = _allocationList[_i];

            if (_amount == 0) continue;

            // Build the call: puppet.execute(transfer to trader)
            bytes memory puppetExecution = abi.encodeWithSelector(
                IERC7579Account.execute.selector,
                ModeLib.encodeSimpleSingle(),
                ExecutionLib.encodeSingle(
                    address(_collateralToken),
                    0,
                    abi.encodeCall(IERC20.transfer, (_traderAddr, _amount))
                )
            );

            // Execute via trader's account with EXECTYPE_TRY - doesn't revert on failure
            // Puppet's policies may reject
            bytes[] memory returnData = _trader.executeFromExecutor(
                ModeLib.encode(CALLTYPE_SINGLE, EXECTYPE_TRY, MODE_DEFAULT, ModePayload.wrap(0x00)),
                ExecutionLib.encodeSingle(_puppet, 0, puppetExecution)
            );

            // EXECTYPE_TRY returns raw result per ERC-7579 spec:
            // - Success: empty bytes (execute() has no return value)
            // - Failure: revert data (error selector + params)
            if (returnData[0].length > 0) continue; // Failed - has revert data

            // Success - update allocation tracking
            uint _newPuppetAllocation = allocationBalance[_traderMatchingKey][_puppet] + _amount;
            allocationBalance[_traderMatchingKey][_puppet] = _newPuppetAllocation;
            _puppetUtilizationList[_i] = _updateUserCheckpoints(_traderMatchingKey, _puppet, _newPuppetAllocation);
            _puppetTotalAllocation += _amount;
        }

        // Handle trader's own allocation (already in trader account)
        uint _traderUtilization = 0;
        if (_traderAllocation > 0) {
            uint _newTraderAllocation = allocationBalance[_traderMatchingKey][_traderAddr] + _traderAllocation;
            allocationBalance[_traderMatchingKey][_traderAddr] = _newTraderAllocation;
            _traderUtilization = _updateUserCheckpoints(_traderMatchingKey, _traderAddr, _newTraderAllocation);
        }

        uint _totalAllocation = _traderAllocation + _puppetTotalAllocation;
        if (_totalAllocation == 0) {
            revert Error.Allocation__ZeroAllocation();
        }

        totalAllocation[_traderMatchingKey] += _totalAllocation;
        subaccountRecordedBalance[_traderMatchingKey] += _totalAllocation;

        _logEvent(
            "Allocate",
            abi.encode(
                _traderMatchingKey,
                _collateralToken,
                _trader,
                _traderAllocation,
                _traderUtilization,
                _puppetTotalAllocation,
                _totalAllocation,
                _puppetList,
                _allocationList,
                _puppetUtilizationList
            )
        );
    }

    // ============ Utilization ============

    function utilize(bytes32 _traderMatchingKey, uint _utilization, bytes calldata _executionCalldata) external auth {
        _utilize(_traderMatchingKey, _utilization, _executionCalldata);
    }

    function _syncSettlement(IERC7579Account _subaccount) internal {
        address _trader = subaccountTraderMap[_subaccount];
        IERC20[] memory _tokens = _subaccountTokenList[_subaccount];
        uint _length = _tokens.length;

        for (uint _i = 0; _i < _length; ++_i) {
            IERC20 _token = _tokens[_i];
            bytes32 _traderMatchingKey = PositionUtils.getTraderMatchingKey(_token, _trader);

            if (totalUtilization[_traderMatchingKey] == 0) continue;

            uint _actualBalance = _token.balanceOf(address(_subaccount));
            uint _recordedBalance = subaccountRecordedBalance[_traderMatchingKey];
            if (_actualBalance <= _recordedBalance) continue;

            _settle(_traderMatchingKey, _token, address(_subaccount), _actualBalance, _recordedBalance);
        }
    }

    function _syncUtilization(IERC7579Account _subaccount, bytes calldata _executionCalldata) internal {
        address _trader = subaccountTraderMap[_subaccount];
        IERC20[] memory _tokens = _subaccountTokenList[_subaccount];
        uint _length = _tokens.length;

        for (uint _i = 0; _i < _length; ++_i) {
            IERC20 _token = _tokens[_i];
            bytes32 _traderMatchingKey = PositionUtils.getTraderMatchingKey(_token, _trader);

            uint _recordedBalance = subaccountRecordedBalance[_traderMatchingKey];
            if (_recordedBalance == 0) continue;

            uint _actualBalance = _token.balanceOf(address(_subaccount));
            if (_actualBalance >= _recordedBalance) continue;

            uint _outflow = _recordedBalance - _actualBalance;
            _utilize(_traderMatchingKey, _outflow, _executionCalldata);
        }
    }

    function _utilize(bytes32 _traderMatchingKey, uint _utilization, bytes calldata _executionCalldata) internal {
        uint _totalAlloc = totalAllocation[_traderMatchingKey];
        if (_totalAlloc == 0) revert Error.Allocation__ZeroAllocation();

        uint _epoch = currentEpoch[_traderMatchingKey];
        uint _remaining = epochRemaining[_traderMatchingKey][_epoch];
        uint _newRemaining = (_remaining * (_totalAlloc - _utilization)) / _totalAlloc;
        epochRemaining[_traderMatchingKey][_epoch] = _newRemaining;

        uint _newTotalUtilization = totalUtilization[_traderMatchingKey] + _utilization;
        uint _newTotalAllocation = _totalAlloc - _utilization;
        totalUtilization[_traderMatchingKey] = _newTotalUtilization;
        totalAllocation[_traderMatchingKey] = _newTotalAllocation;
        subaccountRecordedBalance[_traderMatchingKey] -= _utilization;

        _logEvent(
            "Utilize",
            abi.encode(
                _traderMatchingKey,
                _epoch,
                _utilization,
                _newRemaining,
                _newTotalUtilization,
                _newTotalAllocation,
                _executionCalldata
            )
        );
    }

    // ============ Settlement ============

    function settle(bytes32 _traderMatchingKey, IERC20 _collateralToken) external auth {
        if (totalUtilization[_traderMatchingKey] == 0) revert Error.Allocation__NoUtilization();

        address _subaccount = address(subaccountMap[_traderMatchingKey]);
        uint _actualBalance = _collateralToken.balanceOf(_subaccount);
        uint _recordedBalance = subaccountRecordedBalance[_traderMatchingKey];

        _settle(_traderMatchingKey, _collateralToken, _subaccount, _actualBalance, _recordedBalance);
    }

    function _settle(
        bytes32 _traderMatchingKey,
        IERC20 _collateralToken,
        address _subaccount,
        uint _actualBalance,
        uint _recordedBalance
    ) internal {
        uint _totalUtil = totalUtilization[_traderMatchingKey];
        uint _settledAllocation = _actualBalance - _recordedBalance;
        subaccountRecordedBalance[_traderMatchingKey] = _actualBalance;

        uint _deltaPerUtilization = (_settledAllocation * PRECISION) / _totalUtil;
        uint _newCumulative = cumulativeSettlementPerUtilization[_traderMatchingKey] + _deltaPerUtilization;
        cumulativeSettlementPerUtilization[_traderMatchingKey] = _newCumulative;

        _logEvent(
            "Settle",
            abi.encode(
                _traderMatchingKey,
                _collateralToken,
                _subaccount,
                _settledAllocation,
                _totalUtil,
                _deltaPerUtilization,
                _newCumulative
            )
        );
    }

    function realize(bytes32 _traderMatchingKey, address _user) external auth returns (uint _realized) {
        uint _utilization = getUserUtilization(_traderMatchingKey, _user);
        _realized = pendingSettlement(_traderMatchingKey, _user, _utilization);

        if (_utilization == 0 && _realized == 0) return 0;

        uint _epoch = currentEpoch[_traderMatchingKey];

        if (_realized == 0 && userEpoch[_traderMatchingKey][_user] < _epoch) {
            uint _allocation = allocationBalance[_traderMatchingKey][_user];
            userEpoch[_traderMatchingKey][_user] = _epoch;
            userRemainingCheckpoint[_traderMatchingKey][_user] = epochRemaining[_traderMatchingKey][_epoch];
            userAllocationSnapshot[_traderMatchingKey][_user] = _allocation;
            userSettlementCheckpoint[_traderMatchingKey][_user] =
                cumulativeSettlementPerUtilization[_traderMatchingKey];

            _logEvent("Realize", abi.encode(_traderMatchingKey, _user, _epoch, 0, 0, _allocation));
            return 0;
        }

        if (_utilization > 0) {
            totalUtilization[_traderMatchingKey] -= _utilization;
        }

        if (_realized > 0) {
            totalAllocation[_traderMatchingKey] += _realized;
        }

        uint _newAllocation = allocationBalance[_traderMatchingKey][_user] + _realized - _utilization;
        allocationBalance[_traderMatchingKey][_user] = _newAllocation;

        userEpoch[_traderMatchingKey][_user] = _epoch;
        userRemainingCheckpoint[_traderMatchingKey][_user] = epochRemaining[_traderMatchingKey][_epoch];
        userAllocationSnapshot[_traderMatchingKey][_user] = _newAllocation;
        userSettlementCheckpoint[_traderMatchingKey][_user] = cumulativeSettlementPerUtilization[_traderMatchingKey];

        _logEvent("Realize", abi.encode(_traderMatchingKey, _user, _epoch, _realized, _utilization, _newAllocation));
    }

    // ============ Withdraw ============

    function withdraw(IERC20 _collateralToken, bytes32 _traderMatchingKey, address _user, uint _amount) external auth {
        uint _utilization = getUserUtilization(_traderMatchingKey, _user);
        uint _realized = 0;

        uint _allocation = allocationBalance[_traderMatchingKey][_user];

        if (_utilization > 0) {
            _realized = pendingSettlement(_traderMatchingKey, _user, _utilization);
            if (_realized == 0) {
                revert Error.Allocation__UtilizationNotSettled(_utilization);
            }

            totalUtilization[_traderMatchingKey] -= _utilization;
            totalAllocation[_traderMatchingKey] += _realized;
            _allocation = _allocation + _realized - _utilization;
            allocationBalance[_traderMatchingKey][_user] = _allocation;

            uint _epoch = currentEpoch[_traderMatchingKey];
            userEpoch[_traderMatchingKey][_user] = _epoch;
            userRemainingCheckpoint[_traderMatchingKey][_user] = epochRemaining[_traderMatchingKey][_epoch];
            userAllocationSnapshot[_traderMatchingKey][_user] = _allocation;
            userSettlementCheckpoint[_traderMatchingKey][_user] =
                cumulativeSettlementPerUtilization[_traderMatchingKey];
        }

        if (_allocation < _amount) {
            revert Error.Allocation__InsufficientAllocation(_allocation, _amount);
        }

        uint _newAllocation = _allocation - _amount;
        allocationBalance[_traderMatchingKey][_user] = _newAllocation;
        totalAllocation[_traderMatchingKey] -= _amount;
        _updateUserCheckpoints(_traderMatchingKey, _user, _newAllocation, 0);

        // Transfer from trader subaccount back to puppet's subaccount
        address _traderSubaccount = address(subaccountMap[_traderMatchingKey]);
        _collateralToken.safeTransferFrom(_traderSubaccount, _user, _amount);
        subaccountRecordedBalance[_traderMatchingKey] -= _amount;

        _logEvent(
            "Withdraw",
            abi.encode(_traderMatchingKey, _collateralToken, _user, _amount, _realized, _utilization, _newAllocation)
        );
    }

    // ============ Internal ============

    function _updateUserCheckpoints(bytes32 _traderMatchingKey, address _user, uint _allocation)
        internal
        returns (uint _utilization)
    {
        _utilization = getUserUtilization(_traderMatchingKey, _user);
        _updateUserCheckpoints(_traderMatchingKey, _user, _allocation, _utilization);
    }

    function _updateUserCheckpoints(
        bytes32 _traderMatchingKey,
        address _user,
        uint _allocation,
        uint _utilization
    ) internal {
        if (_utilization == 0) {
            uint _epoch = currentEpoch[_traderMatchingKey];
            userEpoch[_traderMatchingKey][_user] = _epoch;
            userRemainingCheckpoint[_traderMatchingKey][_user] = epochRemaining[_traderMatchingKey][_epoch];
            userAllocationSnapshot[_traderMatchingKey][_user] = _allocation;
            userSettlementCheckpoint[_traderMatchingKey][_user] =
                cumulativeSettlementPerUtilization[_traderMatchingKey];
        }
    }

    function _setConfig(bytes memory _data) internal override {
        Config memory _config = abi.decode(_data, (Config));
        if (_config.maxPuppetList == 0) revert("Invalid max puppet list");
        config = _config;
    }
}
