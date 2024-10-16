// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import {CoreContract} from "../utils/CoreContract.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";

import {MirrorPositionStore} from "./store/MirrorPositionStore.sol";
import {GmxPositionUtils} from "./utils/GmxPositionUtils.sol";

contract UnhandledCallbackLogic is CoreContract {
    MirrorPositionStore immutable positionStore;

    constructor(
        IAuthority _authority,
        MirrorPositionStore _positionStore
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
    //     MirrorPositionStore.UnhandledCallback memory callbackData = positionStore.getUnhandledCallback(key);

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
