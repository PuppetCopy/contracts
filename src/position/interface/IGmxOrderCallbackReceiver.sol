// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.31;

import {GmxPositionUtils} from "./../utils/GmxPositionUtils.sol";

interface IGmxOrderCallbackReceiver {
    /// @dev called after an order execution
    /// @param key the key of the order
    /// @param orderData the order data encoded as EventLogData
    /// @param eventData the event data from execution
    function afterOrderExecution(
        bytes32 key,
        GmxPositionUtils.EventLogData memory orderData,
        GmxPositionUtils.EventLogData memory eventData
    ) external;

    /// @dev called after an order cancellation
    /// @param key the key of the order
    /// @param orderData the order data encoded as EventLogData
    /// @param eventData the event data from cancellation
    function afterOrderCancellation(
        bytes32 key,
        GmxPositionUtils.EventLogData memory orderData,
        GmxPositionUtils.EventLogData memory eventData
    ) external;

    /// @dev called after an order has been frozen, see OrderUtils.freezeOrder in OrderHandler for more info
    /// @param key the key of the order
    /// @param orderData the order data encoded as EventLogData
    /// @param eventData the event data from freezing
    function afterOrderFrozen(
        bytes32 key,
        GmxPositionUtils.EventLogData memory orderData,
        GmxPositionUtils.EventLogData memory eventData
    ) external;

    /// @dev called to refund the execution fee of an order
    /// @param key the key of the order
    /// @param eventData the event data
    function refundExecutionFee(
        bytes32 key,
        GmxPositionUtils.EventLogData memory eventData
    ) external payable;
}
