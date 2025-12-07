// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.31;

import {GmxPositionUtils} from "./../utils/GmxPositionUtils.sol";

interface IGmxOrderCallbackReceiver {
    /// @dev called after an order execution
    /// @param key the key of the order
    /// @param order the order that was executed
    function afterOrderExecution(
        bytes32 key,
        GmxPositionUtils.Props calldata order,
        GmxPositionUtils.EventLogData calldata eventData
    ) external;

    /// @dev called after an order cancellation
    /// @param key the key of the order
    /// @param order the order that was cancelled
    function afterOrderCancellation(
        bytes32 key,
        GmxPositionUtils.Props calldata order,
        GmxPositionUtils.EventLogData calldata eventData
    ) external;

    /// @dev called after an order has been frozen, see OrderUtils.freezeOrder in OrderHandler for more info
    /// @param key the key of the order
    /// @param order the order that was frozen
    function afterOrderFrozen(
        bytes32 key,
        GmxPositionUtils.Props calldata order,
        GmxPositionUtils.EventLogData calldata eventData
    ) external;

    /// @dev called to refund the execution fee of an order
    /// @param key the key of the order
    /// @param eventData the event data that was passed to the order execution
    /// @notice this function is called when the order execution fails, and the execution fee needs
    function refundExecutionFee(
        bytes32 key, //
        GmxPositionUtils.EventLogData calldata eventData
    ) external payable;
}
