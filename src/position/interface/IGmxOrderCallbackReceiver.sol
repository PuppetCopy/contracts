// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import {GmxPositionUtils} from "./../utils/GmxPositionUtils.sol";

interface IGmxOrderCallbackReceiver {
    /// @dev called after an order execution
    /// @param key the key of the order
    /// @param order the order that was executed
    function afterOrderExecution(bytes32 key, GmxPositionUtils.Props memory order, bytes memory eventData) external;

    /// @dev called after an order cancellation
    /// @param key the key of the order
    /// @param order the order that was cancelled
    function afterOrderCancellation(
        bytes32 key,
        GmxPositionUtils.Props memory order,
        bytes memory eventData
    ) external;

    /// @dev called after an order has been frozen, see OrderUtils.freezeOrder in OrderHandler for more info
    /// @param key the key of the order
    /// @param order the order that was frozen
    function afterOrderFrozen(bytes32 key, GmxPositionUtils.Props memory order, bytes memory eventData) external;
}
