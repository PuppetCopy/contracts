// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {GmxPositionUtils} from "./util/GmxPositionUtils.sol";
import {Subaccount} from "./util/Subaccount.sol";
import {Calc} from "./../utils/Calc.sol";
import {PuppetUtils} from "./util/PuppetUtils.sol";

import {RequestIncreasePosition} from "./logic/RequestIncreasePosition.sol";
import {RequestDecreasePosition} from "./logic/RequestDecreasePosition.sol";
import {ExecutePosition} from "./logic/ExecutePosition.sol";
import {GmxOrder} from "./logic/GmxOrder.sol";
import {PositionStore} from "./store/PositionStore.sol";

import {SubaccountLogic} from "./util/SubaccountLogic.sol";
import {SubaccountStore} from "./store/SubaccountStore.sol";

contract PositionLogic is Auth {
    event PositionLogic__CreateTraderSubaccount(address account, address subaccount);

    constructor(Authority _authority) Auth(address(0), _authority) {}

    struct CallCreateSubaccountConfig {
        SubaccountLogic subaccountLogic;
        SubaccountStore subaccountStore;
    }

    function requestIncreasePosition(RequestIncreasePosition.CallConfig calldata callConfig, GmxOrder.CallParams calldata callParams, address from)
        external
        payable
        requiresAuth
    {
        Subaccount subaccount = callConfig.subaccountStore.getSubaccount(from);
        address subaccountAddress = address(subaccount);

        if (subaccountAddress == address(0)) {
            subaccount = callConfig.subaccountLogic.createSubaccount(callConfig.subaccountStore, from);
        }

        PositionStore.RequestAdjustment memory request = PositionStore.RequestAdjustment({
            routeKey: PuppetUtils.getRouteKey(subaccount.account(), callParams.collateralToken),
            positionKey: GmxPositionUtils.getPositionKey(address(subaccount), callParams.market, callParams.collateralToken, callParams.isLong),
            collateralToken: IERC20(callParams.collateralToken),
            subaccount: subaccount,
            trader: from,
            puppetCollateralDeltaList: new uint[](callParams.puppetList.length),
            targetLeverage: 0,
            collateralDelta: callParams.collateralDelta,
            sizeDelta: int(callParams.sizeDelta)
        });

        PositionStore.MirrorPosition memory mirrorPosition = callConfig.positionStore.getMirrorPosition(request.positionKey);

        if (callConfig.positionStore.getPendingRequestMap(request.positionKey).targetLeverage != 0) {
            revert PositionLogic__PendingIncreaseRequestExists();
        }

        if (mirrorPosition.size == 0) {
            RequestIncreasePosition.open(callConfig, callParams, request, subaccountAddress);
        } else {
            RequestIncreasePosition.adjust(callConfig, callParams, mirrorPosition, request);
        }
    }

    function requestDecreasePosition(RequestDecreasePosition.CallConfig calldata callConfig, GmxOrder.CallParams calldata callParams, address from)
        external
        payable
        requiresAuth
    {
        Subaccount subaccount = callConfig.subaccountStore.getSubaccount(from);
        address subaccountAddress = address(subaccount);

        if (subaccountAddress == address(0)) revert PositionLogic__SubaccountNotFound(from);

        bytes32 positionKey = GmxPositionUtils.getPositionKey(address(subaccount), callParams.market, callParams.collateralToken, callParams.isLong);

        PositionStore.MirrorPosition memory mirrorPosition = callConfig.positionStore.getMirrorPosition(positionKey);

        PositionStore.RequestAdjustment memory request = PositionStore.RequestAdjustment({
            routeKey: PuppetUtils.getRouteKey(subaccount.account(), callParams.collateralToken),
            positionKey: positionKey,
            collateralToken: IERC20(callParams.collateralToken),
            subaccount: subaccount,
            trader: from,
            puppetCollateralDeltaList: new uint[](callParams.puppetList.length),
            targetLeverage: (mirrorPosition.size - callParams.sizeDelta) * Calc.BASIS_POINT_DIVISOR
                / (mirrorPosition.collateral - callParams.collateralDelta),
            collateralDelta: callParams.collateralDelta,
            sizeDelta: int(callParams.sizeDelta)
        });

        if (callConfig.positionStore.getPendingRequestMap(request.positionKey).targetLeverage != 0) {
            revert PositionLogic__PendingIncreaseRequestExists();
        }

        RequestDecreasePosition.reduce(callConfig, callParams, mirrorPosition, request);
    }

    function handlIncreaseCallback(
        ExecutePosition.CallbackIncreaseConfig calldata callConfig,
        bytes32 key,
        GmxPositionUtils.Props calldata order,
        bytes calldata eventData
    ) external requiresAuth {
        return ExecutePosition.increase(callConfig, key, order, eventData);
    }

    function handlDecreaseCallback(
        ExecutePosition.CallbackDecreaseConfig calldata callConfig,
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

    error PositionLogic__PendingIncreaseRequestExists();
    error PositionLogic__SubaccountNotFound(address from);
}
