// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {WNT} from "./../utils/WNT.sol";

import {IGmxExchangeRouter} from "./interface/IGmxExchangeRouter.sol";
import {IGmxOrderCallbackReceiver} from "./interface/IGmxOrderCallbackReceiver.sol";
import {IGmxEventUtils} from "./interface/IGmxEventUtils.sol";
import {PositionUtils} from "./util/PositionUtils.sol";
import {Subaccount} from "./util/Subaccount.sol";

import {IncreasePosition} from "./logic/IncreasePosition.sol";
import {SubaccountStore} from "./store/SubaccountStore.sol";
import {PositionStore} from "./store/PositionStore.sol";

contract PositionLogic is Auth {
    event PositionLogic__CreateTraderSubaccount(address account, address subaccount);

    constructor(Authority _authority) Auth(address(0), _authority) {}

    function createTraderSubaccount(WNT _wnt, SubaccountStore store, address trader) external {
        if (address(store.getSubaccount(trader)) == trader) revert PositionLogic__TraderProxyAlreadyExists();

        Subaccount subaccount = new Subaccount(_wnt, store, trader);
        store.setSubaccount(trader, subaccount);

        emit PositionLogic__CreateTraderSubaccount(trader, address(subaccount));
    }

    function requestMatchPosition(
        PositionUtils.CallPositionConfig calldata callConfig,
        PositionUtils.CallPositionAdjustment calldata callPositionAdjustment,
        address[] calldata puppetList
    ) external requiresAuth {
        IncreasePosition.requestMatchPosition(callConfig, callPositionAdjustment, puppetList);
    }

    function requestIncreasePosition(
        PositionUtils.CallPositionConfig calldata callConfig,
        PositionUtils.CallPositionAdjustment calldata callPositionAdjustment
    ) external requiresAuth {
        IncreasePosition.requestIncreasePosition(callConfig, callPositionAdjustment);
    }

    function executeIncreasePosition(
        PositionUtils.CallbackCallPositionConfig calldata callConfig,
        PositionStore.CallbackResponse memory callbackResponse
    ) internal requiresAuth {
        // IncreasePosition.requestDecreasePosition(callConfig, callPositionAdjustment);
    }

    function handlOperatorCallback(
        PositionUtils.CallbackCallPositionConfig calldata callConfig,
        bytes32 key,
        PositionUtils.Props calldata order,
        bytes calldata eventData
    ) external requiresAuth {
        if (callConfig.gmxCallbackOperator != callConfig.caller) revert PositionLogic__UnauthorizedCaller();
        // store callback data, the rest of the logic will attempt to execute the callback data
        // in case of failure we can recovery the callback data and attempt to execute it again
        PositionStore.CallbackResponse memory callbackResponse = PositionStore.CallbackResponse({key: key, order: order, eventData: eventData});
        callConfig.positionStore.setCallbackResponse(key, callbackResponse);

        if (PositionUtils.isIncreaseOrder(order.numbers.orderType)) {
            return executeIncreasePosition(callConfig, callbackResponse);
        } else if (PositionUtils.isDecreaseOrder(order.numbers.orderType)) {
            // return executeDecreasePosition(callConfig, callbackResponse);
        }

        // try executeIncreasePosition(callConfig, callbackResponse) {
        //     // callConfig.positionStore.removeCallbackResponse(callbackResponse.key);
        // } catch {
        //     // if the callback execution fails, we will attempt to execute it again
        // }
    }

    function handlCancelledCallback(
        PositionUtils.CallbackCallPositionConfig calldata callConfig,
        bytes32 key,
        PositionUtils.Props calldata order,
        bytes calldata eventData
    ) external requiresAuth {
        if (callConfig.gmxCallbackOperator != callConfig.caller) revert PositionLogic__UnauthorizedCaller();
        // store callback data, the rest of the logic will attempt to execute the callback data
        // in case of failure we can recovery the callback data and attempt to execute it again
        PositionStore.CallbackResponse memory callbackResponse = PositionStore.CallbackResponse({key: key, order: order, eventData: eventData});
        callConfig.positionStore.setCallbackResponse(key, callbackResponse);

        // if (PositionUtils.isIncreaseOrder(order.numbers.orderType)) {
        //     try executeIncreasePosition(callConfig, callbackResponse) {
        //         // callConfig.positionStore.removeCallbackResponse(callbackResponse.key);
        //     } catch {
        //         // if the callback execution fails, we will attempt to execute it again
        //     }
        // } else if (PositionUtils.isDecreaseOrder(order.numbers.orderType)) {
        //     // return executeDecreasePosition(callConfig, callbackResponse);
        // }
    }

    function handlFrozenCallback(
        PositionUtils.CallbackCallPositionConfig calldata callConfig,
        bytes32 key,
        PositionUtils.Props calldata order,
        bytes calldata eventData
    ) external requiresAuth {
        if (callConfig.gmxCallbackOperator != callConfig.caller) revert PositionLogic__UnauthorizedCaller();
        // store callback data, the rest of the logic will attempt to execute the callback data
        // in case of failure we can recovery the callback data and attempt to execute it again
        PositionStore.CallbackResponse memory callbackResponse = PositionStore.CallbackResponse({key: key, order: order, eventData: eventData});
        callConfig.positionStore.setCallbackResponse(key, callbackResponse);

        if (PositionUtils.isIncreaseOrder(order.numbers.orderType)) {
            return executeIncreasePosition(callConfig, callbackResponse);
        } else if (PositionUtils.isDecreaseOrder(order.numbers.orderType)) {
            // return executeDecreasePosition(callConfig, callbackResponse);
        }

        // try executeIncreasePosition(callConfig, callbackResponse) {
        //     // callConfig.positionStore.removeCallbackResponse(callbackResponse.key);
        // } catch {
        //     // if the callback execution fails, we will attempt to execute it again
        // }
    }

    error PositionLogic__TraderProxyAlreadyExists();
    error PositionLogic__UnauthorizedCaller();
}
