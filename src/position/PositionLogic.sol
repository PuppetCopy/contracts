// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {GmxPositionUtils} from "./util/GmxPositionUtils.sol";
import {Subaccount} from "./util/Subaccount.sol";

import {RequestIncreasePosition} from "./logic/RequestIncreasePosition.sol";
import {RequestDecreasePosition} from "./logic/RequestDecreasePosition.sol";
import {ExecutePosition} from "./logic/ExecutePosition.sol";
import {GmxOrder} from "./logic/GmxOrder.sol";
import {PositionStore} from "./store/PositionStore.sol";

contract PositionLogic is Auth {
    event PositionLogic__CreateTraderSubaccount(address account, address subaccount);
    event PositionLogic__UnhandledCallback(GmxPositionUtils.OrderExecutionStatus status, bytes32 key, GmxPositionUtils.Props order, bytes eventData);

    constructor(Authority _authority) Auth(address(0), _authority) {}

    function requestIncreasePosition(
        RequestIncreasePosition.CallConfig calldata callConfig,
        GmxOrder.CallParams calldata traderCallParams,
        address from
    ) external payable requiresAuth {
        RequestIncreasePosition.increase(callConfig, traderCallParams, from);
    }

    function requestDecreasePosition(
        RequestDecreasePosition.CallConfig calldata callConfig, //
        GmxOrder.CallParams calldata traderCallParams,
        address from
    ) external payable requiresAuth {
        RequestDecreasePosition.decrease(callConfig, traderCallParams, from);
    }

    function handlExeuctionCallback(
        ExecutePosition.CallConfig calldata callConfig,
        bytes32 key,
        GmxPositionUtils.Props calldata order,
        bytes calldata eventData
    ) public requiresAuth {
        if (GmxPositionUtils.isIncreaseOrder(order.numbers.orderType)) {
            return ExecutePosition.increase(callConfig, key, order);
        } else {
            return ExecutePosition.decrease(callConfig, key, order, eventData);
        }
    }

    function handlDecreaseCallback(
        ExecutePosition.CallConfig calldata callConfig,
        bytes32 key,
        GmxPositionUtils.Props calldata order,
        bytes calldata eventData
    ) external requiresAuth {
        return ExecutePosition.decrease(callConfig, key, order, eventData);
    }

    function handlCancelledCallback(bytes32 key, GmxPositionUtils.Props calldata order, bytes calldata eventData) external requiresAuth {
        // the rest can fail
        // if (GmxPositionUtils.isIncreaseOrder(order.numbers.orderType)) {
        //     return ExecutePosition.increase(callConfig, key, order, eventData);
        // } else if (GmxPositionUtils.isDecreaseOrder(order.numbers.orderType)) {
        //     // return executeDecreasePosition(callConfig, callbackResponse);
        // }
    }

    function handlFrozenCallback(bytes32 key, GmxPositionUtils.Props calldata order, bytes calldata eventData) external requiresAuth {
        // try executeIncreasePosition(callConfig, callbackResponse) {
        //     // callConfig.positionStore.removeCallbackResponse(callbackResponse.key);
        // } catch {
        //     // if the callback execution fails, we will attempt to execute it again
        // }
    }

    function storeUnhandledCallbackrCallback(
        ExecutePosition.CallConfig calldata callConfig,
        bytes32 key,
        GmxPositionUtils.Props calldata order,
        bytes calldata eventData
    ) external {
        callConfig.positionStore.setUnhandledCallbackMap(key, order, eventData);
        emit PositionLogic__UnhandledCallback(GmxPositionUtils.OrderExecutionStatus.Executed, key, order, eventData);
    }

    function executeUnhandledExecutionCallback(
        ExecutePosition.CallConfig calldata callConfig,
        bytes32 key,
        GmxPositionUtils.Props calldata order,
        bytes calldata eventData
    ) external requiresAuth {
        handlExeuctionCallback(callConfig, key, order, eventData);
    }
}
