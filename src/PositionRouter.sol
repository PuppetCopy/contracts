// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

import {ReentrancyGuardTransient} from "./utils/ReentrancyGuardTransient.sol";
import {IAuthority} from "./utils/interfaces/IAuthority.sol";
import {Permission} from "./utils/access/Permission.sol";

import {IGmxOrderCallbackReceiver} from "./position/interface/IGmxOrderCallbackReceiver.sol";
import {GmxPositionUtils} from "./position/utils/GmxPositionUtils.sol";

import {PositionStore} from "./position/store/PositionStore.sol";
import {PositionUtils} from "./position/utils/PositionUtils.sol";

import {RequestIncreasePosition} from "./position/RequestIncreasePosition.sol";
import {RequestDecreasePosition} from "./position/RequestDecreasePosition.sol";
import {ExecuteIncreasePosition} from "./position/ExecuteIncreasePosition.sol";
import {ExecuteDecreasePosition} from "./position/ExecuteDecreasePosition.sol";
import {ExecuteRevertedAdjustment} from "./position/ExecuteRevertedAdjustment.sol";

contract PositionRouter is Permission, EIP712, ReentrancyGuardTransient, IGmxOrderCallbackReceiver {
    struct CallConfig {
        RequestIncreasePosition requestIncrease;
        ExecuteIncreasePosition executeIncrease;
        RequestDecreasePosition requestDecrease;
        ExecuteDecreasePosition executeDecrease;
        ExecuteRevertedAdjustment executeRevertedAdjustment;
    }

    event PositionRouter__SetConfig(uint timestamp, CallConfig callConfig);
    event PositionRouter__UnhandledCallback(GmxPositionUtils.OrderExecutionStatus status, bytes32 key, GmxPositionUtils.Props order, bytes eventData);

    CallConfig callConfig;
    PositionStore positionStore;

    constructor(IAuthority _authority, PositionStore _positionStore, CallConfig memory _callConfig)
        Permission(_authority)
        EIP712("Position Router", "1")
    {
        positionStore = _positionStore;
        _setConfig(_callConfig);
    }

    function requestTraderIncrease(
        PositionUtils.TraderCallParams calldata traderCallParams, //
        address[] calldata puppetList
    ) external nonReentrant {
        callConfig.requestIncrease.traderIncrease(traderCallParams, puppetList, msg.sender);
    }

    function requestTraderDecrease(PositionUtils.TraderCallParams calldata traderCallParams) external nonReentrant {
        callConfig.requestDecrease.traderDecrease(traderCallParams, msg.sender);
    }

    function requestProxyIncrease(
        PositionUtils.TraderCallParams calldata traderCallParams, //
        address[] calldata puppetList,
        address user
    ) external nonReentrant auth {
        callConfig.requestIncrease.proxyIncrease(traderCallParams, puppetList, user);
    }

    function requestProxyDecrease(PositionUtils.TraderCallParams calldata traderCallParams, address user) external nonReentrant auth {
        callConfig.requestDecrease.proxyDecrease(traderCallParams, user);
    }

    // external integration

    // attempt to execute the callback, if
    // in case of failure we can recover the callback to later attempt to execute it again
    function afterOrderExecution(bytes32 key, GmxPositionUtils.Props calldata order, bytes calldata eventData) external nonReentrant auth {
        if (GmxPositionUtils.isIncreaseOrder(order.numbers.orderType)) {
            try callConfig.executeIncrease.increase(key, order) {}
            catch {
                storeUnhandledCallback(GmxPositionUtils.OrderExecutionStatus.ExecutedIncrease, order, key, eventData);
            }
        } else if (GmxPositionUtils.isDecreaseOrder(order.numbers.orderType)) {
            try callConfig.executeDecrease.decrease(key, order, eventData) {}
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
        try callConfig.executeRevertedAdjustment.handleCancelled(key, order) {}
        catch {
            storeUnhandledCallback(GmxPositionUtils.OrderExecutionStatus.Cancelled, order, key, eventData);
        }
    }

    function afterOrderFrozen(bytes32 key, GmxPositionUtils.Props calldata order, bytes calldata eventData) external nonReentrant auth {
        try callConfig.executeRevertedAdjustment.handleFrozen(key, order) {}
        catch {
            storeUnhandledCallback(GmxPositionUtils.OrderExecutionStatus.Frozen, order, key, eventData);
        }
    }

    // integration

    function executeUnhandledExecutionCallback(bytes32 key) external nonReentrant auth {
        PositionStore.UnhandledCallback memory callbackData = positionStore.getUnhandledCallback(key);

        if (callbackData.status == GmxPositionUtils.OrderExecutionStatus.ExecutedIncrease) {
            callConfig.executeIncrease.increase(key, callbackData.order);
        } else if (callbackData.status == GmxPositionUtils.OrderExecutionStatus.ExecutedDecrease) {
            callConfig.executeDecrease.decrease(key, callbackData.order, callbackData.eventData);
        } else if (callbackData.status == GmxPositionUtils.OrderExecutionStatus.Cancelled) {
            callConfig.executeRevertedAdjustment.handleCancelled(key, callbackData.order);
        } else if (callbackData.status == GmxPositionUtils.OrderExecutionStatus.Frozen) {
            callConfig.executeRevertedAdjustment.handleFrozen(key, callbackData.order);
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
        positionStore.setUnhandledCallback(status, order, key, eventData);
        emit PositionRouter__UnhandledCallback(status, key, order, eventData);
    }

    function _setConfig(CallConfig memory _callConfig) internal {
        callConfig = _callConfig;

        emit PositionRouter__SetConfig(block.timestamp, callConfig);
    }

    error PositionRouter__InvalidOrderType(GmxPositionUtils.OrderType orderType);
    error PositionRouter__SenderNotMatchingTrader();
}
