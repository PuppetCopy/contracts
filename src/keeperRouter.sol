// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";

import {MatchingRule} from "./position/MatchingRule.sol";
import {MirrorPosition} from "./position/MirrorPosition.sol";
import {Settle} from "./position/Settle.sol";
import {IGmxOrderCallbackReceiver} from "./position/interface/IGmxOrderCallbackReceiver.sol";
import {GmxPositionUtils} from "./position/utils/GmxPositionUtils.sol";
import {AllocationAccount} from "./shared/AllocationAccount.sol";
import {CoreContract} from "./utils/CoreContract.sol";
import {Error} from "./utils/Error.sol";
import {IAuthority} from "./utils/interfaces/IAuthority.sol";

/**
 * @title KeeperRouter
 * @notice Handles keeper-specific operations for the copy trading system
 * @dev Separates keeper operations from user operations for better security and access control
 */
contract KeeperRouter is CoreContract, ReentrancyGuardTransient, IGmxOrderCallbackReceiver {
    struct Config {
        uint mirrorBaseGasLimit;
        uint mirrorPerPuppetGasLimit;
        uint adjustBaseGasLimit;
        uint adjustPerPuppetGasLimit;
        uint settleBaseGasLimit;
        uint settlePerPuppetGasLimit;
        address fallbackRefundExecutionFeeReceiver;
    }

    MatchingRule public immutable matchingRule;
    MirrorPosition public immutable mirrorPosition;
    Settle public immutable settle;

    Config config;

    constructor(
        IAuthority _authority,
        MirrorPosition _mirrorPosition,
        MatchingRule _matchingRule,
        Settle _settle,
        Config memory _config
    ) CoreContract(_authority, abi.encode(_config)) {
        require(address(_mirrorPosition) != address(0), "MirrorPosition not set correctly");
        require(address(_matchingRule) != address(0), "MatchingRule not set correctly");
        require(address(_allocate) != address(0), "Allocate not set correctly");
        require(address(_settle) != address(0), "Settle not set correctly");

        mirrorPosition = _mirrorPosition;
        matchingRule = _matchingRule;
        settle = _settle;
    }

    /**
     * @notice Get gas configuration for keeper operations
     * @return Current gas configuration
     */
    function getConfig() external view returns (Config memory) {
        return config;
    }

    /**
     * @notice Orchestrates mirror position creation by coordinating Allocation and MirrorPosition
     * @param _callParams Position parameters for the trader's position
     * @param _puppetList List of puppet addresses to mirror the position
     * @return _allocationAddress The allocation address created for the position
     * @return _requestKey The GMX request key for the submitted position
     */
    function requestMirror(
        MirrorPosition.CallPosition calldata _callParams,
        address[] calldata _puppetList
    ) external payable auth nonReentrant returns (address _allocationAddress, bytes32 _requestKey) {
        return mirrorPosition.requestOpen{value: msg.value}(matchingRule, _callParams, _puppetList);
    }

    /**
     * @notice Orchestrates position adjustment by coordinating Allocation and MirrorPosition
     * @param _callParams Position parameters for the trader's adjustment
     * @param _allocParams Allocation parameters for keeper fee handling
     * @return _requestKey The GMX request key for the submitted adjustment
     */
    function requestAdjust(
        Allocate.CallAllocation calldata _allocParams,
        MirrorPosition.CallPosition calldata _callParams
    ) external payable auth nonReentrant returns (bytes32 _requestKey) {
        (address allocationAddress, uint nextAllocated) = allocate.collectKeeperFee(_allocParams);

        _requestKey =
            mirrorPosition.requestAdjust{value: msg.value}(_callParams, allocationAddress, nextAllocated, address(this));

        return _requestKey;
    }

    /**
     * @notice Closes a stalled position where the trader has exited but puppet position remains
     * @param _callParams Position parameters for the stalled position
     * @param _allocationAddress The allocation address of the stalled position
     * @return _requestKey The GMX request key for the close order
     */
    function requestCloseStalledPosition(
        MirrorPosition.CallPosition calldata _callParams,
        address _allocationAddress
    ) external payable auth nonReentrant returns (bytes32 _requestKey) {
        _requestKey =
            mirrorPosition.requestCloseStalledPosition{value: msg.value}(_callParams, _allocationAddress, address(this));

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
    function settleAllocation(
        Settle.CallSettle calldata _settleParams,
        address[] calldata _puppetList
    ) external auth nonReentrant returns (uint settledBalance, uint distributionAmount, uint platformFeeAmount) {
        return settle.settle(allocate, _settleParams, _puppetList);
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
        return settle.collectDust(AllocationAccount(_allocationAccount), _dustToken, _receiver);
    }

    /**
     * @notice Internal function to set gas configuration
     * @param _data Encoded configuration data containing the Config struct
     */
    function _setConfig(
        bytes memory _data
    ) internal override {
        Config memory _config = abi.decode(_data, (Config));

        require(_config.mirrorBaseGasLimit > 0, "Invalid mirror base gas limit");
        require(_config.mirrorPerPuppetGasLimit > 0, "Invalid mirror per-puppet gas limit");
        require(_config.adjustBaseGasLimit > 0, "Invalid adjust base gas limit");
        require(_config.adjustPerPuppetGasLimit > 0, "Invalid adjust per-puppet gas limit");

        config = _config;
    }

    /**
     * @notice GMX callback handler for successful order execution
     * @dev Called by GMX when an order is successfully executed
     * @param key The request key for the executed order
     * @param order Order details from GMX
     */
    function afterOrderExecution(
        bytes32 key,
        GmxPositionUtils.Props calldata order,
        GmxPositionUtils.EventLogData calldata /* eventData */
    ) external auth nonReentrant {
        if (
            GmxPositionUtils.isIncreaseOrder(GmxPositionUtils.OrderType(order.numbers.orderType))
                || GmxPositionUtils.isDecreaseOrder(GmxPositionUtils.OrderType(order.numbers.orderType))
        ) {
            // Call MirrorPosition.execute for successful order execution
            mirrorPosition.execute(key);
        } else if (GmxPositionUtils.isLiquidateOrder(GmxPositionUtils.OrderType(order.numbers.orderType))) {
            // Handle liquidation by calling MirrorPosition.liquidate
            mirrorPosition.liquidate(order.addresses.account);
        }
        // Note: Invalid order types are silently ignored to avoid reverting GMX callbacks
    }

    /**
     * @notice GMX callback handler for order cancellation
     * @dev Called by GMX when an order is cancelled
     */
    function afterOrderCancellation(
        bytes32, /* key */
        GmxPositionUtils.Props calldata, /* order */
        GmxPositionUtils.EventLogData calldata /* eventData */
    ) external auth nonReentrant {
        // For now, cancellations are handled silently
        // Future implementation could add retry logic or cleanup
    }

    /**
     * @notice GMX callback handler for frozen orders
     * @dev Called by GMX when an order is frozen
     */
    function afterOrderFrozen(
        bytes32, /* key */
        GmxPositionUtils.Props calldata, /* order */
        GmxPositionUtils.EventLogData calldata /* eventData */
    ) external auth nonReentrant {
        // For now, frozen orders are handled silently
        // Future implementation could add retry logic or cleanup
    }

    /**
     * @notice GMX callback handler for execution fee refunds
     * @dev Called by GMX when execution fees need to be refunded
     * @param key The request key for the refunded order
     */
    function refundExecutionFee(
        bytes32 key,
        GmxPositionUtils.EventLogData calldata /* eventData */
    ) external payable auth nonReentrant {
        require(msg.value > 0, "No execution fee to refund");

        // Refund the execution fee to the configured receiver
        (bool success,) = config.fallbackRefundExecutionFeeReceiver.call{value: msg.value}("");
        require(success, Error.KeeperRouter__FailedRefundExecutionFee());

        _logEvent("RefundExecutionFee", abi.encode(key, msg.value));
    }
}
