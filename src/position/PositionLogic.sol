// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {PositionUtils} from "./util/PositionUtils.sol";
import {Subaccount} from "./util/Subaccount.sol";

import {IncreasePosition} from "./logic/IncreasePosition.sol";
import {PositionStore} from "./store/PositionStore.sol";

contract PositionLogic is Auth {
    event PositionLogic__CreateTraderSubaccount(address account, address subaccount);

    constructor(Authority _authority) Auth(address(0), _authority) {}

    function requestIncreasePosition(IncreasePosition.CallConfig calldata callConfig, IncreasePosition.CallParams calldata callIncreaseParams)
        external
        requiresAuth
    {
        IncreasePosition.requestIncreasePosition(callConfig, callIncreaseParams);
    }

    function handlOperatorCallback(
        IncreasePosition.CallbackConfig calldata callConfig,
        bytes32 key,
        PositionUtils.Props calldata order,
        bytes calldata eventData
    ) external requiresAuth {
        if (PositionUtils.isIncreaseOrder(order.numbers.orderType)) {
            return IncreasePosition.executeIncreasePosition(callConfig, key, order, eventData);
        } else if (PositionUtils.isDecreaseOrder(order.numbers.orderType)) {
            // return executeDecreasePosition(callConfig, callbackResponse);
        }
    }

    function handlCancelledCallback(
        IncreasePosition.CallbackConfig calldata callConfig,
        bytes32 key,
        PositionUtils.Props calldata order,
        bytes calldata eventData
    ) external requiresAuth {
        // the rest can fail
        if (PositionUtils.isIncreaseOrder(order.numbers.orderType)) {
            return IncreasePosition.executeIncreasePosition(callConfig, key, order, eventData);
        } else if (PositionUtils.isDecreaseOrder(order.numbers.orderType)) {
            // return executeDecreasePosition(callConfig, callbackResponse);
        }
    }

    function handlFrozenCallback(
        IncreasePosition.CallbackConfig calldata callConfig,
        bytes32 key,
        PositionUtils.Props calldata order,
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
}
