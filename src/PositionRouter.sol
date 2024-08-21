// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {ReentrancyGuardTransient} from "./utils/ReentrancyGuardTransient.sol";

import {Permission} from "./utils/access/Permission.sol";
import {IAuthority} from "./utils/interfaces/IAuthority.sol";

import {IGmxOrderCallbackReceiver} from "./position/interface/IGmxOrderCallbackReceiver.sol";
import {GmxPositionUtils} from "./position/utils/GmxPositionUtils.sol";

import {PositionStore} from "./position/store/PositionStore.sol";
import {PositionUtils} from "./position/utils/PositionUtils.sol";

import {ExecuteDecreasePositionLogic} from "./position/ExecuteDecreasePositionLogic.sol";
import {ExecuteIncreasePositionLogic} from "./position/ExecuteIncreasePositionLogic.sol";
import {ExecuteRevertedAdjustmentLogic} from "./position/ExecuteRevertedAdjustmentLogic.sol";
import {RequestDecreasePositionLogic} from "./position/RequestDecreasePositionLogic.sol";
import {RequestIncreasePositionLogic} from "./position/RequestIncreasePositionLogic.sol";

contract PositionRouter is Permission, ReentrancyGuardTransient, IGmxOrderCallbackReceiver {
    struct Config {
        RequestIncreasePositionLogic requestIncrease;
        ExecuteIncreasePositionLogic executeIncrease;
        RequestDecreasePositionLogic requestDecrease;
        ExecuteDecreasePositionLogic executeDecrease;
        ExecuteRevertedAdjustmentLogic executeRevertedAdjustment;
    }

    event PositionRouter__SetConfig(uint timestamp, Config config);
    event PositionRouter__UnhandledCallback(
        GmxPositionUtils.OrderExecutionStatus status, bytes32 key, GmxPositionUtils.Props order, bytes eventData
    );

    Config config;
    PositionStore positionStore;

    constructor(IAuthority _authority, PositionStore _positionStore, Config memory _config) Permission(_authority) {
        positionStore = _positionStore;
        _setConfig(_config);
    }

    function requestTraderIncrease(
        PositionUtils.TraderCallParams calldata traderCallParams, //
        address[] calldata puppetList
    ) external nonReentrant {
        config.requestIncrease.traderIncrease(traderCallParams, puppetList, msg.sender);
    }

    function requestTraderDecrease(PositionUtils.TraderCallParams calldata traderCallParams) external nonReentrant {
        config.requestDecrease.traderDecrease(traderCallParams, msg.sender);
    }

    function requestProxyIncrease(
        PositionUtils.TraderCallParams calldata traderCallParams, //
        address[] calldata puppetList,
        address user
    ) external nonReentrant auth {
        config.requestIncrease.proxyIncrease(traderCallParams, puppetList, user);
    }

    function requestProxyDecrease(
        PositionUtils.TraderCallParams calldata traderCallParams,
        address user
    ) external nonReentrant auth {
        config.requestDecrease.proxyDecrease(traderCallParams, user);
    }

    // external integration

    // attempt to execute the callback, if
    // in case of failure we can recover the callback to later attempt to execute it again
    function afterOrderExecution(
        bytes32 key,
        GmxPositionUtils.Props calldata order,
        bytes calldata eventData
    ) external nonReentrant auth {
        if (GmxPositionUtils.isIncreaseOrder(order.numbers.orderType)) {
            try config.executeIncrease.execute(key, order) {}
            catch {
                storeUnhandledCallback(GmxPositionUtils.OrderExecutionStatus.ExecutedIncrease, order, key, eventData);
            }
        } else if (GmxPositionUtils.isDecreaseOrder(order.numbers.orderType)) {
            try config.executeDecrease.execute(key, order, eventData) {}
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
        try config.executeRevertedAdjustment.handleCancelled(key, order) {}
        catch {
            storeUnhandledCallback(GmxPositionUtils.OrderExecutionStatus.Cancelled, order, key, eventData);
        }
    }

    function afterOrderFrozen(
        bytes32 key,
        GmxPositionUtils.Props calldata order,
        bytes calldata eventData
    ) external nonReentrant auth {
        try config.executeRevertedAdjustment.handleFrozen(key, order) {}
        catch {
            storeUnhandledCallback(GmxPositionUtils.OrderExecutionStatus.Frozen, order, key, eventData);
        }
    }

    // integration

    function executeUnhandledExecutionCallback(bytes32 key) external nonReentrant auth {
        PositionStore.UnhandledCallback memory callbackData = positionStore.getUnhandledCallback(key);

        if (callbackData.status == GmxPositionUtils.OrderExecutionStatus.ExecutedIncrease) {
            config.executeIncrease.execute(key, callbackData.order);
        } else if (callbackData.status == GmxPositionUtils.OrderExecutionStatus.ExecutedDecrease) {
            config.executeDecrease.execute(key, callbackData.order, callbackData.eventData);
        } else if (callbackData.status == GmxPositionUtils.OrderExecutionStatus.Cancelled) {
            config.executeRevertedAdjustment.handleCancelled(key, callbackData.order);
        } else if (callbackData.status == GmxPositionUtils.OrderExecutionStatus.Frozen) {
            config.executeRevertedAdjustment.handleFrozen(key, callbackData.order);
        }
    }

    // governance

    function setConfig(Config memory _config) external auth {
        _setConfig(_config);
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

    function _setConfig(Config memory _config) internal {
        config = _config;

        emit PositionRouter__SetConfig(block.timestamp, config);
    }

    error PositionRouter__InvalidOrderType(GmxPositionUtils.OrderType orderType);
    error PositionRouter__SenderNotMatchingTrader();
}
