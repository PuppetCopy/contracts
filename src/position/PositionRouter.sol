// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {Permission} from "../utils/access/Permission.sol";

import {IGmxOrderCallbackReceiver} from "./interface/IGmxOrderCallbackReceiver.sol";
import {GmxPositionUtils} from "./util/GmxPositionUtils.sol";
import {PositionUtils} from "./util/PositionUtils.sol";

import {PositionStore} from "./store/PositionStore.sol";
import {RequestIncreasePosition} from "./logic/RequestIncreasePosition.sol";
import {RequestDecreasePosition} from "./logic/RequestDecreasePosition.sol";
import {ExecuteIncreasePosition} from "./logic/ExecuteIncreasePosition.sol";
import {ExecuteDecreasePosition} from "./logic/ExecuteDecreasePosition.sol";
import {ExecuteRejectedAdjustment} from "./logic/ExecuteRejectedAdjustment.sol";

contract PositionRouter is Permission, EIP712, ReentrancyGuard, IGmxOrderCallbackReceiver {
    struct CallConfig {
        RequestIncreasePosition.CallConfig increase;
        RequestDecreasePosition.CallConfig decrease;
        ExecuteIncreasePosition.CallConfig executeIncrease;
        ExecuteDecreasePosition.CallConfig executeDecrease;
    }

    event PositionRouter__SetConfig(uint timestamp, CallConfig callConfig);
    event PositionRouter__UnhandledCallback(GmxPositionUtils.OrderExecutionStatus status, bytes32 key, GmxPositionUtils.Props order, bytes eventData);

    CallConfig callConfig;

    constructor(IAuthority _authority, CallConfig memory _callConfig) Permission(_authority) EIP712("Position Router", "1") {
        _setConfig(_callConfig);
    }

    function requestIncrease(PositionUtils.TraderCallParams calldata traderCallParams, address[] calldata puppetList) external payable nonReentrant {
        if (traderCallParams.account != msg.sender) revert PositionRouter__SenderNotMatchingTrader();

        RequestIncreasePosition.traderIncrease(callConfig.increase, traderCallParams, puppetList);
    }

    function requestDecrease(PositionUtils.TraderCallParams calldata traderCallParams) external payable nonReentrant {
        RequestDecreasePosition.traderDecrease(callConfig.decrease, traderCallParams);
    }

    // external integration

    // attempt to execute the callback, if
    // in case of failure we can recover the callback to later attempt to execute it again
    function afterOrderExecution(bytes32 key, GmxPositionUtils.Props calldata order, bytes calldata eventData) external nonReentrant auth {
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

    function afterOrderCancellation(
        bytes32 key, //
        GmxPositionUtils.Props calldata order,
        bytes calldata eventData
    ) external nonReentrant auth {
        try ExecuteRejectedAdjustment.handleCancelled(key, order) {}
        catch {
            storeUnhandledCallback(GmxPositionUtils.OrderExecutionStatus.Cancelled, order, key, eventData);
        }
    }

    function afterOrderFrozen(bytes32 key, GmxPositionUtils.Props calldata order, bytes calldata eventData) external nonReentrant auth {
        try ExecuteRejectedAdjustment.handleFrozen(key, order) {}
        catch {
            storeUnhandledCallback(GmxPositionUtils.OrderExecutionStatus.Frozen, order, key, eventData);
        }
    }

    function proxyRequestIncrease(
        PositionUtils.TraderCallParams calldata traderCallParams, //
        address[] calldata puppetList
    ) external payable auth {
        RequestIncreasePosition.proxyIncrease(callConfig.increase, traderCallParams, puppetList);
    }

    function proxyRequestDecrease(PositionUtils.TraderCallParams calldata traderCallParams) external payable auth {
        RequestDecreasePosition.proxyDecrease(callConfig.decrease, traderCallParams);
    }

    // integration

    function executeUnhandledExecutionCallback(bytes32 key) external nonReentrant auth {
        PositionStore.UnhandledCallback memory callbackData = callConfig.executeIncrease.positionStore.getUnhandledCallback(key);

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

    function setConfig(CallConfig memory _callConfig) external auth {
        _setConfig(_callConfig);
    }

    // internal

    function storeUnhandledCallback(
        GmxPositionUtils.OrderExecutionStatus status,
        GmxPositionUtils.Props calldata order,
        bytes32 key,
        bytes calldata eventData
    ) internal auth {
        callConfig.executeIncrease.positionStore.setUnhandledCallback(status, order, key, eventData);
        emit PositionRouter__UnhandledCallback(status, key, order, eventData);
    }

    function _setConfig(CallConfig memory _callConfig) internal {
        callConfig = _callConfig;

        emit PositionRouter__SetConfig(block.timestamp, callConfig);
    }

    error PositionRouter__InvalidOrderType(GmxPositionUtils.OrderType orderType);
    error PositionRouter__SenderNotMatchingTrader();
}
