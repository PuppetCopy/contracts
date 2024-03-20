// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {IGmxOrderCallbackReceiver} from "./position/interface/IGmxOrderCallbackReceiver.sol";
import {RequestIncreasePosition} from "./position/logic/RequestIncreasePosition.sol";
import {ExecutePosition} from "./position/logic/ExecutePosition.sol";
import {GmxPositionUtils} from "./position/util/GmxPositionUtils.sol";
import {PositionLogic} from "./position/PositionLogic.sol";
import {GmxOrder} from "./position/logic/GmxOrder.sol";

contract PositionRouter is Auth, ReentrancyGuard, IGmxOrderCallbackReceiver {
    event PositionRouter__SetConfig(
        uint timestamp,
        RequestIncreasePosition.CallConfig callIncreaseConfig,
        ExecutePosition.CallbackIncreaseConfig increaseCallbackConfig,
        ExecutePosition.CallbackDecreaseConfig decreaseCallbackConfig
    );

    PositionLogic positionLogic;

    RequestIncreasePosition.CallConfig public callIncreaseConfig;
    ExecutePosition.CallbackIncreaseConfig public increaseCallbackConfig;
    ExecutePosition.CallbackDecreaseConfig public decreaseCallbackConfig;

    constructor(
        Authority _authority,
        PositionLogic _positionLogic,
        RequestIncreasePosition.CallConfig memory _callIncreaseConfig,
        ExecutePosition.CallbackIncreaseConfig memory _increaseCallback,
        ExecutePosition.CallbackDecreaseConfig memory _decreaseCallback
    ) Auth(address(0), _authority) {
        positionLogic = _positionLogic;
        _setConfig(_callIncreaseConfig, _increaseCallback, _decreaseCallback);
    }

    function request(GmxOrder.CallParams calldata callParams) external payable nonReentrant {
        positionLogic.requestIncreasePosition{value: msg.value}(callIncreaseConfig, callParams, msg.sender);
    }

    function afterOrderExecution(bytes32 key, GmxPositionUtils.Props calldata order, bytes calldata eventData) external nonReentrant {
        // _handlOperatorCallback(key, order, eventData);

        if (GmxPositionUtils.isIncreaseOrder(order.numbers.orderType)) {
            return positionLogic.handlIncreaseCallback(increaseCallbackConfig, key, order, eventData);
        } else {
            return positionLogic.handlDecreaseCallback(decreaseCallbackConfig, key, order, eventData);
        }
    }

    function afterOrderCancellation(bytes32 key, GmxPositionUtils.Props calldata order, bytes calldata eventData) external nonReentrant {
        // _handlOperatorCallback(key, order, eventData);
    }

    function afterOrderFrozen(bytes32 key, GmxPositionUtils.Props calldata order, bytes calldata eventData) external nonReentrant {
        // _handlOperatorCallback(key, order, eventData);
    }

    // governance

    function setPositionLogic(PositionLogic _positionLogic) external requiresAuth {
        positionLogic = _positionLogic;
    }

    function setConfig(
        RequestIncreasePosition.CallConfig memory _callIncreaseConfig,
        ExecutePosition.CallbackIncreaseConfig memory _increaseCallback,
        ExecutePosition.CallbackDecreaseConfig memory _decreaseCallback
    ) external requiresAuth {
        _setConfig(_callIncreaseConfig, _increaseCallback, _decreaseCallback);
    }

    function _setConfig(
        RequestIncreasePosition.CallConfig memory _callIncreaseConfig,
        ExecutePosition.CallbackIncreaseConfig memory _increaseCallback,
        ExecutePosition.CallbackDecreaseConfig memory _decreaseCallback
    ) internal {
        callIncreaseConfig = _callIncreaseConfig;
        increaseCallbackConfig = _increaseCallback;
        decreaseCallbackConfig = _decreaseCallback;

        emit PositionRouter__SetConfig(block.timestamp, _callIncreaseConfig, _increaseCallback, _decreaseCallback);
    }

    error PositionLogic__UnauthorizedCaller();
}
