// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {AllocationAccount} from "../shared/AllocationAccount.sol";
import {AllocationStore} from "../shared/AllocationStore.sol";
import {CoreContract} from "../utils/CoreContract.sol";
import {Error} from "../utils/Error.sol";
import {Precision} from "../utils/Precision.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {MatchingRule} from "./MatchingRule.sol";
import {PositionUtils} from "./utils/PositionUtils.sol";

/**
 * @title Allocate
 * @notice Manages allocation logic for puppet copy trading
 * @dev Handles creation and management of allocation accounts for puppets following traders
 */
contract Allocate is CoreContract {
    struct Config {
        uint transferOutGasLimit;
        uint maxPuppetList;
        uint maxKeeperFeeToAllocationRatio;
        uint maxKeeperFeeToAdjustmentRatio;
        address gmxOrderVault;
    }

    struct CallAllocation {
        IERC20 collateralToken;
        address trader;
        address[] puppetList;
        uint allocationId;
        uint keeperFee;
        address keeperFeeReceiver;
    }

    AllocationStore public immutable allocationStore;
    address public immutable allocationAccountImplementation;

    Config config;

    // Allocation tracking
    mapping(address allocationAddress => uint totalAmount) public allocationMap;
    mapping(address allocationAddress => uint[] puppetAmounts) public allocationPuppetList;
    mapping(bytes32 traderMatchingKey => mapping(address puppet => uint lastActivity)) public lastActivityThrottleMap;

    constructor(
        IAuthority _authority,
        AllocationStore _allocationStore,
        Config memory _config
    ) CoreContract(_authority, abi.encode(_config)) {
        allocationStore = _allocationStore;
        allocationAccountImplementation = address(new AllocationAccount(_allocationStore));
    }

    function getConfig() external view returns (Config memory) {
        return config;
    }

    /**
     * @notice Get total allocation for an address
     */
    function getAllocation(
        address _allocationAddress
    ) external view returns (uint) {
        return allocationMap[_allocationAddress];
    }

    /**
     * @notice Get puppet allocations for an address
     */
    function getPuppetAllocationList(
        address _allocationAddress
    ) external view returns (uint[] memory) {
        return allocationPuppetList[_allocationAddress];
    }

    /**
     * @notice Initialize trader activity throttle
     */
    function initializeTraderActivityThrottle(bytes32 _traderMatchingKey, address _puppet) external auth {
        lastActivityThrottleMap[_traderMatchingKey][_puppet] = 1;
    }

    /**
     * @notice Creates allocations for puppets following a trader
     * @dev Calculates how much each puppet allocates based on their rules and balances
     * @return _allocationAddress The deterministic address for this allocation
     * @return _allocated The total amount allocated after keeper fee
     */
    function createAllocation(
        MatchingRule _matchingRule,
        CallAllocation calldata _params
    ) external auth returns (address _allocationAddress, uint _allocated) {
        uint _puppetCount = _params.puppetList.length;
        require(_puppetCount > 0, Error.Allocation__PuppetListEmpty());

        bytes32 _traderMatchingKey = PositionUtils.getTraderMatchingKey(_params.collateralToken, _params.trader);
        bytes32 _allocationKey =
            PositionUtils.getAllocationKey(_params.puppetList, _traderMatchingKey, _params.allocationId);

        _allocationAddress = Clones.cloneDeterministic(allocationAccountImplementation, _allocationKey);

        // Get rules and balances
        MatchingRule.Rule[] memory _rules = _matchingRule.getRuleList(_traderMatchingKey, _params.puppetList);
        uint[] memory _balanceList = allocationStore.getBalanceList(_params.collateralToken, _params.puppetList);

        uint _feePerPuppet = _params.keeperFee / _puppetCount;
        uint _totalAllocated = 0;

        uint[] memory _allocationList = new uint[](_puppetCount);
        allocationPuppetList[_allocationAddress] = new uint[](_puppetCount);

        for (uint _i = 0; _i < _puppetCount; _i++) {
            address _puppet = _params.puppetList[_i];
            MatchingRule.Rule memory _rule = _rules[_i];

            if (
                _rule.expiry > block.timestamp
                    && block.timestamp >= lastActivityThrottleMap[_traderMatchingKey][_puppet]
            ) {
                uint _puppetAllocation = Precision.applyBasisPoints(_rule.allowanceRate, _balanceList[_i]);

                if (_feePerPuppet > Precision.applyFactor(config.maxKeeperFeeToAllocationRatio, _puppetAllocation)) {
                    continue;
                }

                _allocationList[_i] = _puppetAllocation;
                allocationPuppetList[_allocationAddress][_i] = _puppetAllocation;
                _balanceList[_i] -= _puppetAllocation;
                _totalAllocated += _puppetAllocation;
                lastActivityThrottleMap[_traderMatchingKey][_puppet] = block.timestamp + _rule.throttleActivity;
            }
        }

        allocationStore.setBalanceList(_params.collateralToken, _params.puppetList, _balanceList);

        require(
            _params.keeperFee < Precision.applyFactor(config.maxKeeperFeeToAllocationRatio, _totalAllocated),
            Error.Allocation__KeeperFeeExceedsCostFactor(_params.keeperFee, _totalAllocated)
        );

        _allocated = _totalAllocated - _params.keeperFee;
        allocationMap[_allocationAddress] = _allocated;

        allocationStore.transferOut(
            config.transferOutGasLimit, _params.collateralToken, _params.keeperFeeReceiver, _params.keeperFee
        );
        allocationStore.transferOut(
            config.transferOutGasLimit, _params.collateralToken, config.gmxOrderVault, _allocated
        );

        _logEvent(
            "CreateAllocation", abi.encode(_params, _allocationAddress, _totalAllocated, _allocated, _allocationList)
        );
    }

    /**
     * @notice Updates allocations when handling keeper fees for adjustments
     * @dev Reduces puppet allocations if they can't afford their share of keeper fee
     * @return _allocationAddress The allocation account address
     * @return _nextAllocated The updated total allocation after deducting insolvencies
     */
    function collectKeeperFee(
        CallAllocation calldata _params
    ) external auth returns (address _allocationAddress, uint _nextAllocated) {
        bytes32 _traderMatchingKey = PositionUtils.getTraderMatchingKey(_params.collateralToken, _params.trader);
        bytes32 _allocationKey =
            PositionUtils.getAllocationKey(_params.puppetList, _traderMatchingKey, _params.allocationId);
        _allocationAddress =
            Clones.predictDeterministicAddress(allocationAccountImplementation, _allocationKey, address(this));

        _nextAllocated = allocationMap[_allocationAddress];

        require(_nextAllocated > 0, Error.Allocation__InvalidAllocation(_allocationAddress));
        require(_params.keeperFee > 0, Error.Allocation__InvalidKeeperExecutionFeeAmount());
        require(
            _params.keeperFee < Precision.applyFactor(config.maxKeeperFeeToAdjustmentRatio, _nextAllocated),
            Error.Allocation__KeeperFeeExceedsAdjustmentRatio(_params.keeperFee, _nextAllocated)
        );

        uint[] memory _allocationList = allocationPuppetList[_allocationAddress];
        uint[] memory _balanceList = allocationStore.getBalanceList(_params.collateralToken, _params.puppetList);
        uint _puppetCount = _params.puppetList.length;
        require(
            _allocationList.length == _puppetCount,
            Error.Allocation__PuppetListMismatch(_allocationList.length, _puppetCount)
        );
        require(
            _nextAllocated > _params.keeperFee,
            Error.Allocation__InsufficientAllocationForKeeperFee(_nextAllocated, _params.keeperFee)
        );

        uint _remainingKeeperFeeToCollect = _params.keeperFee;
        uint _keeperExecutionFeeInsolvency = 0;
        for (uint _i = 0; _i < _puppetCount; _i++) {
            uint _puppetAllocation = _allocationList[_i];

            if (_puppetAllocation == 0) continue;

            // Calculate execution fee more precisely to avoid rounding errors
            uint _remainingPuppets = _puppetCount - _i;
            uint _executionFee = (_remainingKeeperFeeToCollect + _remainingPuppets - 1) / _remainingPuppets;

            // Ensure we don't exceed remaining fee
            if (_executionFee > _remainingKeeperFeeToCollect) {
                _executionFee = _remainingKeeperFeeToCollect;
            }

            if (_balanceList[_i] >= _executionFee) {
                _balanceList[_i] -= _executionFee;
                _remainingKeeperFeeToCollect -= _executionFee;
            } else {
                _allocationList[_i] = _puppetAllocation >= _executionFee ? _puppetAllocation - _executionFee : 0;
                _keeperExecutionFeeInsolvency += _executionFee;
            }
        }

        require(
            _remainingKeeperFeeToCollect == 0,
            Error.Allocation__KeeperFeeNotFullyCovered(0, _remainingKeeperFeeToCollect)
        );

        _nextAllocated -= _keeperExecutionFeeInsolvency;

        require(
            _params.keeperFee < Precision.applyFactor(config.maxKeeperFeeToAdjustmentRatio, _nextAllocated),
            Error.Allocation__KeeperFeeExceedsAdjustmentRatio(_params.keeperFee, _nextAllocated)
        );

        allocationStore.setBalanceList(_params.collateralToken, _params.puppetList, _balanceList);
        allocationPuppetList[_allocationAddress] = _allocationList;
        allocationMap[_allocationAddress] = _nextAllocated;

        allocationStore.transferOut(
            config.transferOutGasLimit, _params.collateralToken, _params.keeperFeeReceiver, _params.keeperFee
        );

        _logEvent(
            "UpdateAllocationForKeeperFee",
            abi.encode(
                // _params, TODO: emit _params intead of individual fields like collateralToken and keeperFee
                _allocationAddress,
                _params.collateralToken,
                _params.keeperFee,
                _nextAllocated,
                _keeperExecutionFeeInsolvency,
                _allocationList
            )
        );

        return (_allocationAddress, _nextAllocated);
    }

    /**
     * @notice Internal function to set configuration
     * @dev Required by CoreContract
     */
    function _setConfig(
        bytes memory _data
    ) internal override {
        Config memory _config = abi.decode(_data, (Config));

        require(_config.maxPuppetList > 0, "Invalid Max Puppet List");
        require(_config.maxKeeperFeeToAllocationRatio > 0, "Invalid Max Keeper Fee To Allocation Ratio");
        require(_config.maxKeeperFeeToAdjustmentRatio > 0, "Invalid Max Keeper Fee To Adjustment Ratio");
        require(_config.gmxOrderVault != address(0), "Invalid GMX Order Vault");

        config = _config;
    }
}
