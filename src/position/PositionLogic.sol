// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {GmxPositionUtils} from "./util/GmxPositionUtils.sol";
import {Subaccount} from "./util/Subaccount.sol";

import {PositionStore} from "./store/PositionStore.sol";

import {RequestIncreasePosition} from "./logic/RequestIncreasePosition.sol";
import {RequestDecreasePosition} from "./logic/RequestDecreasePosition.sol";
import {ExecutePosition} from "./logic/ExecutePosition.sol";
import {GmxOrder} from "./logic/GmxOrder.sol";

contract PositionLogic is Auth {
    event PositionLogic__CreateTraderSubaccount(address account, address subaccount);

    constructor(Authority _authority) Auth(address(0), _authority) {}

    function requestIncreasePosition(
        GmxOrder.CallConfig calldata gmxCallConfig,
        RequestIncreasePosition.RequestConfig calldata callConfig,
        GmxOrder.CallParams calldata callParams
    ) external requiresAuth {
        RequestIncreasePosition.call(gmxCallConfig, callConfig, callParams);
    }

    function handlOperatorCallback(
        ExecutePosition.CallConfig calldata callConfig,
        bytes32 key,
        GmxPositionUtils.Props calldata order,
        bytes calldata eventData
    ) external requiresAuth {
        if (GmxPositionUtils.isIncreaseOrder(order.numbers.orderType)) {
            return ExecutePosition.increase(callConfig, key, order, eventData);
        } else {
            return ExecutePosition.decrease(callConfig, key, order, eventData);
        }
    }

    function handlCancelledCallback(
        ExecutePosition.CallConfig calldata callConfig,
        bytes32 key,
        GmxPositionUtils.Props calldata order,
        bytes calldata eventData
    ) external requiresAuth {
        // the rest can fail
        if (GmxPositionUtils.isIncreaseOrder(order.numbers.orderType)) {
            return ExecutePosition.increase(callConfig, key, order, eventData);
        } else if (GmxPositionUtils.isDecreaseOrder(order.numbers.orderType)) {
            // return executeDecreasePosition(callConfig, callbackResponse);
        }
    }

    function handlFrozenCallback(
        ExecutePosition.CallConfig calldata callConfig,
        bytes32 key,
        GmxPositionUtils.Props calldata order,
        bytes calldata eventData
    ) external requiresAuth {
        // try executeIncreasePosition(callConfig, callbackResponse) {
        //     // callConfig.positionStore.removeCallbackResponse(callbackResponse.key);
        // } catch {
        //     // if the callback execution fails, we will attempt to execute it again
        // }
    }

    error PositionLogic__TraderProxyAlreadyExists();
    error PositionLogic__UnauthorizedCaller();
    error PositionLogic__InvalidSubaccountTrader();
}
