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
        uint timestamp, GmxOrder.CallConfig gmxCallConfig, RequestIncreasePosition.RequestConfig callConfig, ExecutePosition.CallConfig executeConfig
    );

    PositionLogic positionLogic;

    GmxOrder.CallConfig gmxCallConfig;
    RequestIncreasePosition.RequestConfig callRequestConfig;
    ExecutePosition.CallConfig callExecuteConfig;

    constructor(
        Authority _authority,
        PositionLogic _positionLogic,
        GmxOrder.CallConfig memory _gmxCallConfig,
        RequestIncreasePosition.RequestConfig memory _callConfig,
        ExecutePosition.CallConfig memory _executeConfig
    ) Auth(address(0), _authority) {
        positionLogic = _positionLogic;
        _setConfig(_gmxCallConfig, _callConfig, _executeConfig);
    }

    function request(GmxOrder.CallParams calldata callParams) external nonReentrant {
        positionLogic.requestIncreasePosition(gmxCallConfig, callRequestConfig, callParams, msg.sender);
    }

    function afterOrderExecution(bytes32 key, GmxPositionUtils.Props calldata order, bytes calldata eventData) external nonReentrant {
        _handlOperatorCallback(key, order, eventData);
    }

    function afterOrderCancellation(bytes32 key, GmxPositionUtils.Props calldata order, bytes calldata eventData) external nonReentrant {
        _handlOperatorCallback(key, order, eventData);
    }

    function afterOrderFrozen(bytes32 key, GmxPositionUtils.Props calldata order, bytes calldata eventData) external nonReentrant {
        _handlOperatorCallback(key, order, eventData);
    }

    // internal

    function _handlOperatorCallback(bytes32 key, GmxPositionUtils.Props calldata order, bytes calldata eventData) internal {
        if (callExecuteConfig.gmxOrderHandler != msg.sender) revert PositionLogic__UnauthorizedCaller();

        try positionLogic.handlOperatorCallback(callExecuteConfig, key, order, eventData) {}
        catch {
            // store callback data, the rest of the logic will attempt to execute the callback data
            // in case of failure we can recovery the callback data and attempt to execute it again
            callExecuteConfig.positionStore.setUnhandledCallbackMap(key, order, eventData);
        }
    }

    // governance

    function setConfig(
        GmxOrder.CallConfig calldata _gmxCallConfig,
        RequestIncreasePosition.RequestConfig calldata _callConfig,
        ExecutePosition.CallConfig calldata _executeConfig
    ) external requiresAuth {
        _setConfig(_gmxCallConfig, _callConfig, _executeConfig);
    }

    function _setConfig(
        GmxOrder.CallConfig memory _gmxCallConfig,
        RequestIncreasePosition.RequestConfig memory _callConfig,
        ExecutePosition.CallConfig memory _executeConfig
    ) internal {
        gmxCallConfig = _gmxCallConfig;
        callRequestConfig = _callConfig;
        callExecuteConfig = _executeConfig;

        emit PositionRouter__SetConfig(block.timestamp, _gmxCallConfig, _callConfig, _executeConfig);
    }

    error PositionLogic__UnauthorizedCaller();
}
