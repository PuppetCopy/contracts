// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import {CoreContract} from "../utils/CoreContract.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";

import {PositionStore} from "./store/PositionStore.sol";
import {GmxPositionUtils} from "./utils/GmxPositionUtils.sol";

contract UnhandledCallbackLogic is CoreContract {
    PositionStore immutable positionStore;

    constructor(
        IAuthority _authority,
        PositionStore _positionStore
    ) CoreContract("UnhandledCallbackLogic", "1", _authority) {
        positionStore = _positionStore;
    }

    function storeUnhandledCallback(
        GmxPositionUtils.Props calldata order,
        bytes32 key,
        bytes calldata eventData
    ) external auth {
        positionStore.setUnhandledCallback(order, key, eventData);
        _logEvent("StoreUnhandledCallback", abi.encode(key, order, eventData));
    }

    // function executeUnhandledExecutionCallback(
    //     bytes32 key
    // ) external auth {
    //     PositionStore.UnhandledCallback memory callbackData = positionStore.getUnhandledCallback(key);

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

    function _setConfig(
        bytes calldata data
    ) internal override {
        revert("NOT_IMPLEMENTED");
    }
}
