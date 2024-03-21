// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {IGmxOrderCallbackReceiver} from "./position/interface/IGmxOrderCallbackReceiver.sol";
import {RequestIncreasePosition} from "./position/logic/RequestIncreasePosition.sol";
import {RequestDecreasePosition} from "./position/logic/RequestDecreasePosition.sol";
import {ExecutePosition} from "./position/logic/ExecutePosition.sol";
import {GmxPositionUtils} from "./position/util/GmxPositionUtils.sol";
import {PositionLogic} from "./position/PositionLogic.sol";
import {GmxOrder} from "./position/logic/GmxOrder.sol";
import {PositionStore} from "./position/store/PositionStore.sol";

contract PositionRouter is Auth, ReentrancyGuard, IGmxOrderCallbackReceiver {
    event PositionRouter__SetConfig(uint timestamp, RequestIncreasePosition.CallConfig callIncreaseConfig, ExecutePosition.CallConfig callbackConfig);

    PositionLogic positionLogic;

    RequestIncreasePosition.CallConfig callIncreaseConfig;
    RequestDecreasePosition.CallConfig callDecreaseConfig;
    ExecutePosition.CallConfig callbackConfig;

    constructor(
        Authority _authority,
        PositionLogic _positionLogic,
        RequestIncreasePosition.CallConfig memory _callIncreaseConfig,
        RequestDecreasePosition.CallConfig memory _callDecreaseConfig,
        ExecutePosition.CallConfig memory _callbackConfig
    ) Auth(address(0), _authority) {
        positionLogic = _positionLogic;
        _setConfig(_callIncreaseConfig, _callDecreaseConfig, _callbackConfig);
    }

    function requestIncrease(GmxOrder.CallParams calldata traderCallParams) external payable nonReentrant {
        positionLogic.requestIncreasePosition{value: msg.value}(callIncreaseConfig, traderCallParams, msg.sender);
    }

    function requestDecrease(GmxOrder.CallParams calldata traderCallParams) external payable nonReentrant {
        positionLogic.requestDecreasePosition(callDecreaseConfig, traderCallParams, msg.sender);
    }

    function afterOrderExecution(bytes32 key, GmxPositionUtils.Props calldata order, bytes calldata eventData) external nonReentrant {
        try positionLogic.handlExeuctionCallback(callbackConfig, key, order, eventData) {}
        catch {
            // store callback data, the rest of the logic will attempt to execute the callback data
            // in case of failure we can recovery the callback data and attempt to execute it again
            positionLogic.storeUnhandledCallbackrCallback(callbackConfig, key, order, eventData);
        }
    }

    function afterOrderCancellation(bytes32 key, GmxPositionUtils.Props calldata order, bytes calldata eventData) external nonReentrant {
        // _handlOperatorCallback(key, order, eventData);
    }

    function afterOrderFrozen(bytes32 key, GmxPositionUtils.Props calldata order, bytes calldata eventData) external nonReentrant {
        // _handlOperatorCallback(key, order, eventData);
    }

    // governance
    function executeUnhandledExecutionCallback(bytes32 key) external nonReentrant {
        if (callbackConfig.gmxOrderHandler != msg.sender) revert PositionLogic__UnauthorizedCaller();

        PositionStore.UnhandledCallbackMap memory cbState = callbackConfig.positionStore.getUnhandledCallbackMap(key);

        positionLogic.executeUnhandledExecutionCallback(callbackConfig, key, cbState.order, cbState.eventData);
    }

    function setPositionLogic(PositionLogic _positionLogic) external requiresAuth {
        positionLogic = _positionLogic;
    }

    function setConfig(
        RequestIncreasePosition.CallConfig memory _callIncreaseConfig,
        RequestDecreasePosition.CallConfig memory _callDecreaseConfig,
        ExecutePosition.CallConfig memory _callbackConfig
    ) external requiresAuth {
        _setConfig(_callIncreaseConfig, _callDecreaseConfig, _callbackConfig);
    }

    function _setConfig(
        RequestIncreasePosition.CallConfig memory _callIncreaseConfig,
        RequestDecreasePosition.CallConfig memory _callDecreaseConfig,
        ExecutePosition.CallConfig memory _callbackConfig
    ) internal {
        callIncreaseConfig = _callIncreaseConfig;
        callDecreaseConfig = _callDecreaseConfig;
        callbackConfig = _callbackConfig;

        emit PositionRouter__SetConfig(block.timestamp, _callIncreaseConfig, _callbackConfig);
    }

    error PositionLogic__UnauthorizedCaller();
}
