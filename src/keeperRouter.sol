// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";

import {Allocation} from "./position/Allocation.sol";
import {MatchingRule} from "./position/MatchingRule.sol";
import {MirrorPosition} from "./position/MirrorPosition.sol";
import {AllocationAccount} from "./shared/AllocationAccount.sol";
import {FeeMarketplace} from "./shared/FeeMarketplace.sol";
import {CoreContract} from "./utils/CoreContract.sol";
import {IAuthority} from "./utils/interfaces/IAuthority.sol";

/**
 * @title KeeperRouter
 * @notice Handles keeper-specific operations for the copy trading system
 * @dev Separates keeper operations from user operations for better security and access control
 */
contract KeeperRouter is CoreContract, ReentrancyGuardTransient {
    MatchingRule public immutable matchingRule;
    MirrorPosition public immutable mirrorPosition;
    Allocation public immutable allocation;

    constructor(
        IAuthority _authority,
        MirrorPosition _mirrorPosition,
        MatchingRule _matchingRule,
        Allocation _allocation
    ) CoreContract(_authority) {
        require(address(_mirrorPosition) != address(0), "MirrorPosition not set correctly");
        require(address(_matchingRule) != address(0), "MatchingRule not set correctly");
        require(address(_allocation) != address(0), "Allocation not set correctly");

        mirrorPosition = _mirrorPosition;
        matchingRule = _matchingRule;
        allocation = _allocation;
    }

    /**
     * @notice Orchestrates mirror position creation by coordinating Allocation and MirrorPosition
     * @param _allocParams Allocation parameters for puppet fund management
     * @param _callParams Position parameters for the trader's action
     * @return _allocationAddress The allocation account address created
     * @return _requestKey The GMX request key for the submitted order
     */
    function requestMirror(
        Allocation.CallAllocation calldata _allocParams,
        MirrorPosition.CallPosition calldata _callParams
    ) external payable auth nonReentrant returns (address _allocationAddress, bytes32 _requestKey) {
        (address allocationAddress, uint totalAllocated) = allocation.createAllocation(matchingRule, _allocParams);

        _requestKey = mirrorPosition.requestMirror{value: msg.value}(_callParams, allocationAddress, totalAllocated);

        return (allocationAddress, _requestKey);
    }

    /**
     * @notice Orchestrates position adjustment by coordinating Allocation and MirrorPosition
     * @param _callParams Position parameters for the trader's adjustment
     * @param _allocParams Allocation parameters for keeper fee handling
     * @return _requestKey The GMX request key for the submitted adjustment
     */
    function requestAdjust(
        MirrorPosition.CallPosition calldata _callParams,
        Allocation.CallAllocation calldata _allocParams
    ) external payable auth nonReentrant returns (bytes32 _requestKey) {
        (address allocationAddress, uint nextAllocated) = allocation.collectKeeperFee(_allocParams);

        _requestKey = mirrorPosition.requestAdjust{value: msg.value}(_callParams, allocationAddress, nextAllocated);

        return _requestKey;
    }

    /**
     * @notice Settles an allocation by distributing funds back to puppets
     * @param _settleParams Settlement parameters
     * @param _puppetList List of puppet addresses involved
     * @return settledBalance Total amount settled
     * @return distributionAmount Amount distributed to puppets
     * @return platformFeeAmount Platform fee collected
     */
    function settle(
        Allocation.CallSettle calldata _settleParams,
        address[] calldata _puppetList
    ) external auth nonReentrant returns (uint settledBalance, uint distributionAmount, uint platformFeeAmount) {
        return allocation.settle(_settleParams, _puppetList);
    }

    /**
     * @notice Collects dust tokens from an allocation account
     * @param _allocationAccount The allocation account to collect dust from
     * @param _dustToken The token to collect
     * @param _receiver The address to receive the dust
     * @return dustAmount Amount of dust collected
     */
    function collectDust(
        address _allocationAccount,
        IERC20 _dustToken,
        address _receiver
    ) external auth nonReentrant returns (uint dustAmount) {
        return allocation.collectDust(AllocationAccount(_allocationAccount), _dustToken, _receiver);
    }

    /**
     * @notice Get configuration (empty for KeeperRouter)
     * @dev Required by Dictatorship.initContract but not used by KeeperRouter
     */
    function config() external pure returns (bytes memory) {
        return "";
    }

    /**
     * @notice Internal function to set configuration (not used but required by CoreContract)
     * @dev RouterKeeper doesn't have its own configuration
     */
    function _setConfig(
        bytes memory
    ) internal override {
        // RouterKeeper doesn't have configuration to set
        // This function is required by CoreContract but not used
    }
}
