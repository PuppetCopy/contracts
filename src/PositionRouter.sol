// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {IGmxOrderCallbackReceiver} from "./position/interface/IGmxOrderCallbackReceiver.sol";
import {GmxPositionUtils} from "./position/util/GmxPositionUtils.sol";

import {PositionStore} from "./position/store/PositionStore.sol";
import {RequestIncreasePosition} from "./position/logic/RequestIncreasePosition.sol";
import {RequestDecreasePosition} from "./position/logic/RequestDecreasePosition.sol";
import {ExecuteIncreasePosition} from "./position/logic/ExecuteIncreasePosition.sol";
import {ExecuteDecreasePosition} from "./position/logic/ExecuteDecreasePosition.sol";
import {ExecuteRejectedAdjustment} from "./position/logic/ExecuteRejectedAdjustment.sol";

contract PositionRouter is Auth, ReentrancyGuard, IGmxOrderCallbackReceiver {
    struct CallConfig {
        RequestIncreasePosition.CallConfig increase;
        RequestDecreasePosition.CallConfig decrease;
        ExecuteIncreasePosition.CallConfig executeIncrease;
        ExecuteDecreasePosition.CallConfig executeDecrease;
    }

    event PositionRouter__SetConfig(uint timestamp, CallConfig callConfig);
    event PositionRouter__UnhandledCallback(GmxPositionUtils.OrderExecutionStatus status, bytes32 key, GmxPositionUtils.Props order, bytes eventData);

    CallConfig callConfig;

    constructor(Authority _authority, CallConfig memory _callConfig) Auth(address(0), _authority) {
        _setConfig(_callConfig);
    }

    function requestIncrease(RequestIncreasePosition.TraderCallParams calldata traderCallParams) external payable nonReentrant {
        RequestIncreasePosition.increase(callConfig.increase, traderCallParams, msg.sender);
    }

    function requestDecrease(RequestDecreasePosition.TraderCallParams calldata traderCallParams) external payable nonReentrant {
        RequestDecreasePosition.decrease(callConfig.decrease, traderCallParams, msg.sender);
    }

    // attempt to execute the callback, if
    // in case of failure we can recover the callback to later attempt to execute it again
    function afterOrderExecution(bytes32 key, GmxPositionUtils.Props calldata order, bytes calldata eventData) external nonReentrant requiresAuth {
        if (GmxPositionUtils.isIncreaseOrder(order.numbers.orderType)) {
            try ExecuteIncreasePosition.increase(callConfig.executeIncrease, key, order) {}
            catch {
                storeUnhandledCallback(GmxPositionUtils.OrderExecutionStatus.ExecutedIncrease, order, key, eventData);
            }
        } else if (GmxPositionUtils.isDecreaseOrder(order.numbers.orderType)) {
            try ExecuteDecreasePosition.decrease(callConfig.executeDecrease, key, order, eventData) {}
            catch {
                storeUnhandledCallback(GmxPositionUtils.OrderExecutionStatus.ExecutedDecrease, order, key, eventData);
            }
        } else {
            revert PositionRouter__InvalidOrderType(order.numbers.orderType);
        }
    }

    function afterOrderCancellation(bytes32 key, GmxPositionUtils.Props calldata order, bytes calldata eventData) external nonReentrant {
        try ExecuteRejectedAdjustment.handleCancelled(key, order) {}
        catch {
            storeUnhandledCallback(GmxPositionUtils.OrderExecutionStatus.Cancelled, order, key, eventData);
        }
    }

    function afterOrderFrozen(bytes32 key, GmxPositionUtils.Props calldata order, bytes calldata eventData) external nonReentrant {
        try ExecuteRejectedAdjustment.handleFrozen(key, order) {}
        catch {
            storeUnhandledCallback(GmxPositionUtils.OrderExecutionStatus.Cancelled, order, key, eventData);
        }
    }

    // integration

    function executeUnhandledExecutionCallback(bytes32 key) external nonReentrant requiresAuth {
        PositionStore.UnhandledCallbackMap memory callbackData = callConfig.executeIncrease.positionStore.getUnhandledCallbackMap(key);

        if (callbackData.status == GmxPositionUtils.OrderExecutionStatus.ExecutedIncrease) {
            ExecuteIncreasePosition.increase(callConfig.executeIncrease, key, callbackData.order);
        } else if (callbackData.status == GmxPositionUtils.OrderExecutionStatus.ExecutedDecrease) {
            ExecuteDecreasePosition.decrease(callConfig.executeDecrease, key, callbackData.order, callbackData.eventData);
        } else if (callbackData.status == GmxPositionUtils.OrderExecutionStatus.Cancelled) {
            ExecuteRejectedAdjustment.handleCancelled(key, callbackData.order);
        } else if (callbackData.status == GmxPositionUtils.OrderExecutionStatus.Frozen) {
            ExecuteRejectedAdjustment.handleFrozen(key, callbackData.order);
        }
    }

    // governance

    function setConfig(CallConfig memory _callConfig) external requiresAuth {
        _setConfig(_callConfig);
    }

    // internal

    function storeUnhandledCallback(
        GmxPositionUtils.OrderExecutionStatus status,
        GmxPositionUtils.Props calldata order,
        bytes32 key,
        bytes calldata eventData
    ) internal requiresAuth {
        callConfig.executeIncrease.positionStore.setUnhandledCallbackMap(status, order, key, eventData);
        emit PositionRouter__UnhandledCallback(status, key, order, eventData);
    }

    function _setConfig(CallConfig memory _callConfig) internal {
        callConfig = _callConfig;

        emit PositionRouter__SetConfig(block.timestamp, callConfig);
    }

    error PositionRouter__InvalidOrderType(GmxPositionUtils.OrderType orderType);
}
