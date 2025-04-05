// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {Error} from "../utils/Error.sol";
import {CoreContract} from "../utils/CoreContract.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {Precision} from "./../utils/Precision.sol";
import {MirrorPosition} from "./MirrorPosition.sol";
import {IGmxOrderCallbackReceiver} from "./interface/IGmxOrderCallbackReceiver.sol";
import {GmxPositionUtils} from "./utils/GmxPositionUtils.sol";

contract GmxExecutionCallback is CoreContract, IGmxOrderCallbackReceiver {
    struct UnhandledCallback {
        GmxPositionUtils.Props order;
        address operator;
        bytes eventData;
        bytes32 key;
    }

    MirrorPosition immutable position;

    uint public unhandledCallbackListId = 0;
    mapping(uint unhandledCallbackListSequenceId => UnhandledCallback) public unhandledCallbackMap;

    constructor(IAuthority _authority, MirrorPosition _position) CoreContract(_authority) {
        position = _position;
    }

    function storeUnhandledCallback(
        GmxPositionUtils.Props calldata _order,
        bytes32 _key,
        bytes calldata _eventData
    ) public auth {
        UnhandledCallback memory callbackResponse =
            UnhandledCallback({order: _order, operator: address(this), eventData: _eventData, key: _key});

        uint id = ++unhandledCallbackListId;
        unhandledCallbackMap[id] = callbackResponse;

        _logEvent("StoreUnhandledCallback", abi.encode(id, _key, _order, _eventData));
    }

    /**
     * @notice Called after an order is executed.
     */
    function afterOrderExecution(
        bytes32 key,
        GmxPositionUtils.Props calldata order,
        bytes calldata /*eventData*/
    ) external auth {
        if (
            GmxPositionUtils.isIncreaseOrder(order.numbers.orderType)
                || GmxPositionUtils.isDecreaseOrder(order.numbers.orderType)
        ) {
            position.execute(key);
        } else {
            revert Error.GmxExecutionCallback__InvalidOrderType(order.numbers.orderType);
        }
    }

    /**
     * @notice Called after an order is cancelled.
     */
    function afterOrderCancellation(
        bytes32 key,
        GmxPositionUtils.Props calldata order,
        bytes calldata eventData
    ) external auth {
        revert("Not implemented");
        // try handleCancelled(key, order, eventData) {
        //     // Successful cancellation handling
        // } catch {
        //     storeUnhandledCallback(order, key, eventData);
        // }
    }

    /**
     * @notice Called after an order is frozen.
     */
    function afterOrderFrozen(
        bytes32 key,
        GmxPositionUtils.Props calldata order,
        bytes calldata eventData
    ) external auth {
        revert("Not implemented");
        // try handleFrozen(key, order, eventData) {
        //     // Successful frozen handling
        // } catch {
        //     storeUnhandledCallback(order, key, eventData);
        // }
    }

    // function executeUnhandledExecutionCallback(
    //     bytes32 key
    // ) external auth {
    //     PositionStore.UnhandledCallback memory callbackData = position.getUnhandledCallback(key);

    //     if (callbackData.status == GmxPositionUtils.OrderExecutionStatus.ExecutedIncrease) {
    //         config.executeIncrease.execute(key, callbackData.order, callbackData.eventData);
    //     } else if (callbackData.status == GmxPositionUtils.OrderExecutionStatus.ExecutedDecrease) {
    //         config.executeDecrease.execute(key, callbackData.order, callbackData.eventData);
    //     } else if (callbackData.status == GmxPositionUtils.OrderExecutionStatus.Cancelled) {
    //         config.executeRevertedAdjustment.handleCancelled(key, callbackData.order);
    //     } else if (callbackData.status == GmxPositionUtils.OrderExecutionStatus.Frozen) {
    //         config.executeRevertedAdjustment.handleFrozen(key, callbackData.order);
    //     }
    // }
}
