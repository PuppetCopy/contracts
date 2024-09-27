// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {ExecuteDecreasePositionLogic} from "./position/ExecuteDecreasePositionLogic.sol";
import {ExecuteIncreasePositionLogic} from "./position/ExecuteIncreasePositionLogic.sol";
import {ExecuteRevertedAdjustmentLogic} from "./position/ExecuteRevertedAdjustmentLogic.sol";
import {SettleLogic} from "./position/SettleLogic.sol";
import {IGmxOrderCallbackReceiver} from "./position/interface/IGmxOrderCallbackReceiver.sol";
import {MirrorPositionStore} from "./position/store/MirrorPositionStore.sol";
import {GmxPositionUtils} from "./position/utils/GmxPositionUtils.sol";
import {Error} from "./shared/Error.sol";
import {CoreContract} from "./utils/CoreContract.sol";
import {EventEmitter} from "./utils/EventEmitter.sol";
import {ReentrancyGuardTransient} from "./utils/ReentrancyGuardTransient.sol";
import {IAuthority} from "./utils/interfaces/IAuthority.sol";

contract PositionRouter is CoreContract, ReentrancyGuardTransient, IGmxOrderCallbackReceiver {
    struct Config {
        SettleLogic settleLogic;
        ExecuteIncreasePositionLogic executeIncrease;
        ExecuteDecreasePositionLogic executeDecrease;
        ExecuteRevertedAdjustmentLogic executeRevertedAdjustment;
    }

    Config public config;
    MirrorPositionStore positionStore;

    constructor(
        IAuthority _authority,
        EventEmitter _eventEmitter,
        MirrorPositionStore _positionStore
    ) CoreContract("PositionRouter", "1", _authority, _eventEmitter) {
        positionStore = _positionStore;
    }

    function afterOrderExecution(
        bytes32 key,
        GmxPositionUtils.Props calldata order,
        bytes calldata eventData
    ) external nonReentrant auth {
        if (GmxPositionUtils.isIncreaseOrder(order.numbers.orderType)) {
            try config.executeIncrease.execute(key, order, eventData) {}
            catch {
                storeUnhandledCallback(GmxPositionUtils.OrderExecutionStatus.ExecutedIncrease, order, key, eventData);
            }
        } else if (GmxPositionUtils.isDecreaseOrder(order.numbers.orderType)) {
            try config.executeDecrease.execute(key, order, eventData) {}
            catch {
                storeUnhandledCallback(GmxPositionUtils.OrderExecutionStatus.ExecutedDecrease, order, key, eventData);
            }
        } else {
            revert Error.PositionRouter__InvalidOrderType(order.numbers.orderType);
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

    function executeUnhandledExecutionCallback(bytes32 key) external nonReentrant auth {
        MirrorPositionStore.UnhandledCallback memory callbackData = positionStore.getUnhandledCallback(key);

        if (callbackData.status == GmxPositionUtils.OrderExecutionStatus.ExecutedIncrease) {
            config.executeIncrease.execute(key, callbackData.order, callbackData.eventData);
        } else if (callbackData.status == GmxPositionUtils.OrderExecutionStatus.ExecutedDecrease) {
            config.executeDecrease.execute(key, callbackData.order, callbackData.eventData);
        } else if (callbackData.status == GmxPositionUtils.OrderExecutionStatus.Cancelled) {
            config.executeRevertedAdjustment.handleCancelled(key, callbackData.order);
        } else if (callbackData.status == GmxPositionUtils.OrderExecutionStatus.Frozen) {
            config.executeRevertedAdjustment.handleFrozen(key, callbackData.order);
        }
    }

    // governance

    /// @notice Set the mint rate limit for the token.
    /// @param _config The new rate limit configuration.
    function setConfig(Config calldata _config) external auth {
        config = _config;
        logEvent("SetConfig", abi.encode(_config));
    }

    // internal

    function storeUnhandledCallback(
        GmxPositionUtils.OrderExecutionStatus status,
        GmxPositionUtils.Props calldata order,
        bytes32 key,
        bytes calldata eventData
    ) internal auth {
        positionStore.setUnhandledCallback(status, order, key, eventData);
        logEvent("StoreUnhandledCallback", abi.encode(status, key, order, eventData));
    }
}
