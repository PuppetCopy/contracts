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

/**
 * @title Allocation
 * @notice Two-phase fund management: allocate (staging) → utilize (shares)
 *
 * Flow:
 * 1. allocate() - Master pulls funds from puppets → tracked as idle allocations
 * 2. utilize() - Master converts allocations to shares (proportionally), unused returned
 * 3. withdraw() - Burn shares at current share price (GM-pool style)
 * 4. withdrawAllocation() - Return idle allocations to puppets
 */
contract Allocation is CoreContract, IExecutor, IHook {

    struct Config {
        uint maxPuppetList;
        uint transferOutGasLimit;
        uint callGasLimit;
        uint minFirstDepositShares;
    }

    Config public config;
    mapping(address => INpvReader) public venueReaders;
    uint256 constant EXEC_OFFSET = 100;

    // Idle allocations (staging area - not yet utilized)
    mapping(bytes32 => uint) public totalAllocation;
    mapping(bytes32 => mapping(address => uint)) public allocationBalance;

    // Utilized funds (shares in active positions)
    mapping(bytes32 => uint) public totalShares;
    mapping(bytes32 => mapping(address => uint)) public userShares;

    // Subaccount management
    mapping(bytes32 => IERC7579Account) public subaccountMap;
    mapping(IERC7579Account => IERC20[]) public masterCollateralList;

    // Position tracking
    mapping(bytes32 => INpvReader) public keyReader;
    mapping(address => bytes32[]) public openPositionKeys;
    mapping(address => mapping(bytes32 => uint)) public positionKeyIndex;

    constructor(IAuthority _authority, Config memory _config) CoreContract(_authority, abi.encode(_config)) {}

    function getConfig() external view returns (Config memory) {
        return config;
    }

    // ============ Utilization Value & Share Price ============
    // Note: Utilization value only includes UTILIZED funds (shares), not idle allocations
    // Positions cannot go underwater (liquidated first), so NPV is always >= 0

    function getPositionValue(address _master) public view returns (uint) {
        bytes32[] memory _posKeys = openPositionKeys[_master];
        uint _total = 0;

        for (uint _i = 0; _i < _posKeys.length; ++_i) {
            bytes32 _posKey = _posKeys[_i];
            INpvReader _reader = keyReader[_posKey];
            if (address(_reader) == address(0)) continue;

            int256 _npv = _reader.getPositionNetValue(_posKey);
            if (_npv > 0) _total += uint256(_npv);
        }

        return _total;
    }

    function getUtilizedBalance(bytes32 _key, IERC20 _token) public view returns (uint) {
        address _subaccount = address(subaccountMap[_key]);
        if (_subaccount == address(0)) return 0;

        uint _balance = _token.balanceOf(_subaccount);
        uint _idle = totalAllocation[_key];

        // Utilized balance = total balance - idle allocations
        return _balance > _idle ? _balance - _idle : 0;
    }

    function getUtilizationValue(bytes32 _key, IERC20 _token) public view returns (uint) {
        address _subaccount = address(subaccountMap[_key]);
        if (_subaccount == address(0)) return 0;

        return getUtilizedBalance(_key, _token) + getPositionValue(_subaccount);
    }

    function getSharePrice(bytes32 _key, IERC20 _token) public view returns (uint) {
        uint _supply = totalShares[_key];
        if (_supply == 0) return Precision.FLOAT_PRECISION; // First utilization gets 1:1

        uint _utilizationValue = getUtilizationValue(_key, _token);
        return Precision.toFactor(_utilizationValue, _supply);
    }

    function getUserValue(IERC20 _token, address _master, address _user) external view returns (uint) {
        bytes32 _key = PositionUtils.getMatchingKey(_token, _master);
        uint _shares = userShares[_key][_user];
        uint _sharePrice = getSharePrice(_key, _token);
        return Precision.applyFactor(_sharePrice, _shares);
    }

    // ============ Allocate (Stage Funds) ============

    function allocate(
        IERC20 _collateralToken,
        address _masterAddr,
        address[] calldata _puppetList,
        uint[] calldata _amountList
    ) external auth {
        IERC7579Account _master = IERC7579Account(_masterAddr);
        bool _bothInstalled = _master.isModuleInstalled(MODULE_TYPE_EXECUTOR, address(this), "")
            && _master.isModuleInstalled(MODULE_TYPE_HOOK, address(this), "");
        if (!_bothInstalled) revert Error.Allocation__UnregisteredSubaccount();

        uint _puppetCount = _puppetList.length;
        if (_puppetCount > config.maxPuppetList) {
            revert Error.Allocation__PuppetListTooLarge(_puppetCount, config.maxPuppetList);
        }
        if (_puppetCount != _amountList.length) {
            revert Error.Allocation__ArrayLengthMismatch(_puppetCount, _amountList.length);
        }

        bytes32 _key = PositionUtils.getMatchingKey(_collateralToken, _masterAddr);

        if (address(subaccountMap[_key]) == address(0)) {
            subaccountMap[_key] = _master;
            masterCollateralList[_master].push(_collateralToken);
        }

        uint _totalAllocated = 0;

        for (uint _i = 0; _i < _puppetCount; ++_i) {
            address _puppet = _puppetList[_i];
            uint _amount = _amountList[_i];
            if (_amount == 0) continue;

            bytes memory _result = _executeFromExecutor(
                IERC7579Account(_puppet),
                address(_collateralToken),
                config.callGasLimit,
                abi.encodeCall(IERC20.transfer, (_masterAddr, _amount))
            );

            if (_result.length == 0 || !abi.decode(_result, (bool))) continue;

            allocationBalance[_key][_puppet] += _amount;
            _totalAllocated += _amount;
        }

        if (_totalAllocated == 0) revert Error.Allocation__ZeroAllocation();

        totalAllocation[_key] += _totalAllocated;

        _logEvent("Allocate", abi.encode(_key, _collateralToken, _master, _totalAllocated, _puppetList, _amountList));
    }

    // ============ Utilize (Convert Allocations to Shares) ============

    function utilize(
        IERC20 _collateralToken,
        address _masterAddr,
        address[] calldata _puppetList,
        uint _amountToUtilize
    ) external auth {
        bytes32 _key = PositionUtils.getMatchingKey(_collateralToken, _masterAddr);

        uint _totalAvailable = totalAllocation[_key];
        if (_amountToUtilize > _totalAvailable) {
            revert Error.Allocation__InsufficientAllocation(_totalAvailable, _amountToUtilize);
        }

        // For existing utilizations, validate health (must have value)
        uint _supply = totalShares[_key];
        if (_supply > 0) {
            uint _utilizationValue = getUtilizationValue(_key, _collateralToken);
            if (_utilizationValue == 0) revert Error.Allocation__InvalidPoolState(_supply, 0);
        }

        uint _sharePrice = getSharePrice(_key, _collateralToken);
        uint _totalNewShares = 0;
        uint _totalUtilized = 0;
        uint _totalReturned = 0;

        for (uint _i = 0; _i < _puppetList.length; ++_i) {
            address _puppet = _puppetList[_i];
            uint _puppetAllocation = allocationBalance[_key][_puppet];
            if (_puppetAllocation == 0) continue;

            // Calculate proportional utilization: puppetUtilize = amountToUtilize * puppetAlloc / totalAlloc
            uint _puppetUtilize = (_amountToUtilize * _puppetAllocation) / _totalAvailable;
            uint _puppetReturn = _puppetAllocation - _puppetUtilize;

            if (_puppetUtilize > 0) {
                uint _newShares = Precision.toFactor(_puppetUtilize, _sharePrice);
                userShares[_key][_puppet] += _newShares;
                _totalNewShares += _newShares;
                _totalUtilized += _puppetUtilize;
            }

            if (_puppetReturn > 0) {
                // Return unused allocation to puppet
                bytes memory _result = _executeFromExecutor(
                    subaccountMap[_key],
                    address(_collateralToken),
                    config.transferOutGasLimit,
                    abi.encodeCall(IERC20.transfer, (_puppet, _puppetReturn))
                );

                if (_result.length > 0 && abi.decode(_result, (bool))) {
                    _totalReturned += _puppetReturn;
                } else {
                    // If return fails, keep as allocation
                    _puppetUtilize = _puppetAllocation;
                    _totalUtilized += _puppetReturn;
                }
            }

            allocationBalance[_key][_puppet] = 0;
        }

        if (_totalUtilized == 0) revert Error.Allocation__ZeroAllocation();

        // Enforce minimum shares for first utilization
        bool _isFirstUtilization = _supply == 0;
        if (_isFirstUtilization && _totalNewShares < config.minFirstDepositShares) {
            revert Error.Allocation__InsufficientFirstDeposit(_totalNewShares, config.minFirstDepositShares);
        }

        totalAllocation[_key] -= (_totalUtilized + _totalReturned);
        totalShares[_key] += _totalNewShares;

        _logEvent("Utilize", abi.encode(_key, _collateralToken, _totalUtilized, _totalReturned, _totalNewShares, _sharePrice, _puppetList));
    }

    // ============ Withdraw (Idle Allocations First, Then Shares) ============

    function withdraw(IERC20 _token, bytes32 _key, address _user, uint _amount) external auth {
        uint _remaining = _amount;
        uint _fromAllocation = 0;
        uint _fromShares = 0;
        uint _sharesBurned = 0;

        // 1. Calculate how much comes from idle allocations (1:1 in tokens)
        uint _userAllocation = allocationBalance[_key][_user];
        if (_userAllocation > 0) {
            _fromAllocation = _userAllocation >= _remaining ? _remaining : _userAllocation;
            _remaining -= _fromAllocation;
        }

        // 2. Calculate shares to burn for remaining amount BEFORE modifying state
        //    (share price depends on totalAllocation, so calculate first)
        if (_remaining > 0) {
            // Validate utilization health for share withdrawal
            uint _utilizationValue = getUtilizationValue(_key, _token);
            if (_utilizationValue == 0) revert Error.Allocation__InvalidPoolState(totalShares[_key], 0);

            uint _sharePrice = getSharePrice(_key, _token);
            _sharesBurned = Precision.toFactor(_remaining, _sharePrice);

            uint _userShareBalance = userShares[_key][_user];
            if (_sharesBurned > _userShareBalance) revert Error.Allocation__InsufficientBalance(_userShareBalance, _sharesBurned);

            // Check liquidity
            uint _availableBalance = getUtilizedBalance(_key, _token);
            if (_remaining > _availableBalance) revert Error.Allocation__InsufficientBalance(_availableBalance, _remaining);

            _fromShares = _remaining;
        }

        // 3. Apply state changes
        if (_fromAllocation > 0) {
            allocationBalance[_key][_user] -= _fromAllocation;
            totalAllocation[_key] -= _fromAllocation;
        }
        if (_sharesBurned > 0) {
            userShares[_key][_user] -= _sharesBurned;
            totalShares[_key] -= _sharesBurned;
        }

        // 4. Transfer total amount
        uint _totalTransfer = _fromAllocation + _fromShares;
        if (_totalTransfer > 0) {
            bytes memory _result = _executeFromExecutor(
                subaccountMap[_key], address(_token), config.transferOutGasLimit, abi.encodeCall(IERC20.transfer, (_user, _totalTransfer))
            );

            if (_result.length == 0 || !abi.decode(_result, (bool))) revert Error.Allocation__TransferFailed();

            _logEvent("Withdraw", abi.encode(_key, _token, _user, _fromAllocation, _sharesBurned, _fromShares));
        }
    }

    // ============ Module Interface ============

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
                uint _alloc = totalAllocation[_key];
                if (_shares > 0 || _alloc > 0) revert Error.Allocation__ActiveShares(_shares + _alloc);
            }
            delete masterCollateralList[_master];
        }
    }

    // ============ Hook: Position Tracking ============

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
        }

        return _msgData;
    }

    function postCheck(bytes calldata) external {}

    // ============ Internal ============

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
        // minFirstDepositShares can be 0 to disable the check
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
