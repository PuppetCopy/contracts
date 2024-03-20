// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IGmxEventUtils} from "./../interface/IGmxEventUtils.sol";

import {Router} from "src/utils/Router.sol";
import {GmxPositionUtils} from "../util/GmxPositionUtils.sol";
import {Subaccount} from "../util/Subaccount.sol";

import {PuppetStore} from "../store/PuppetStore.sol";
import {PositionStore} from "../store/PositionStore.sol";
import {PuppetLogic} from "./../PuppetLogic.sol";

library ExecutePosition {
    struct CallbackIncreaseConfig {
        PositionStore positionStore;
        PuppetStore puppetStore;
        PuppetLogic puppetLogic;
        address gmxOrderHandler;
    }

    struct CallbackDecreaseConfig {
        PositionStore positionStore;
        PuppetStore puppetStore;
        PuppetLogic puppetLogic;
        Router router;
        address gmxOrderHandler;
    }

    function increase(CallbackIncreaseConfig calldata callConfig, bytes32 key, GmxPositionUtils.Props calldata order, bytes calldata eventData)
        external
    {
        bytes32 positionKey = GmxPositionUtils.getPositionKey(
            order.addresses.account, order.addresses.market, order.addresses.initialCollateralToken, order.flags.isLong
        );

        PositionStore.RequestAdjustment memory request = callConfig.positionStore.getPendingRequestMap(key);
        PositionStore.MirrorPosition memory mirrorPosition = callConfig.positionStore.getMirrorPosition(positionKey);

        mirrorPosition.collateral += request.collateralDelta;
        if (request.sizeDelta > 0) {
            mirrorPosition.size += uint(request.sizeDelta);
        } else {
            mirrorPosition.size -= uint(-request.sizeDelta);
        }

        callConfig.positionStore.removePendingRequestMap(key);
        callConfig.positionStore.setMirrorPosition(key, mirrorPosition);
    }

    function decrease(CallbackDecreaseConfig calldata callConfig, bytes32 key, GmxPositionUtils.Props calldata order, bytes calldata eventData)
        external
    {
        (IGmxEventUtils.EventLogData memory eventLogData) = abi.decode(eventData, (IGmxEventUtils.EventLogData));

        // Check if there is at least one uint item available
        if (eventLogData.uintItems.items.length == 0 && eventLogData.uintItems.arrayItems.length == 0) {
            revert ExecutePosition__UnexpectedEventData();
        }

        bytes32 positionKey = GmxPositionUtils.getPositionKey(
            order.addresses.account, order.addresses.market, order.addresses.initialCollateralToken, order.flags.isLong
        );
        PositionStore.RequestAdjustment memory request = callConfig.positionStore.getPendingRequestMap(key);

        if (request.targetLeverage == 0) revert ExecutePosition__MissingRequest(positionKey, key);

        PositionStore.MirrorPosition memory mirrorPosition = callConfig.positionStore.getMirrorPosition(positionKey);

        if (mirrorPosition.size == 0) revert ExecutePosition__MissingRequest(positionKey, key);

        mirrorPosition.collateral -= order.numbers.initialCollateralDeltaAmount;
        mirrorPosition.size -= order.numbers.sizeDeltaUsd;

        PuppetStore.Activity[] memory activityList = callConfig.puppetStore.getActivityList(request.routeKey, mirrorPosition.puppetList);

        address outputToken = eventLogData.addressItems.items[0].value;
        uint outputAmount = eventLogData.uintItems.items[0].value;

        for (uint i = 0; i < mirrorPosition.puppetList.length; i++) {
            PuppetStore.Activity memory activity = activityList[i];

            uint collateralDelta = request.puppetCollateralDeltaList[i];

            request.puppetCollateralDeltaList[i] -= collateralDelta;
            request.collateralDelta -= collateralDelta;
            request.sizeDelta -= int(uint(request.sizeDelta) * collateralDelta / mirrorPosition.size);

            activity.allowance += mirrorPosition.collateral * mirrorPosition.puppetDepositList[i] / outputAmount;
            activityList[i] = activity;
        }

        callConfig.puppetLogic.setRouteActivityList(callConfig.puppetStore, request.routeKey, mirrorPosition.puppetList, activityList);
        callConfig.positionStore.removePendingRequestMap(positionKey);

        uint traderAmountOut = mirrorPosition.collateral * request.collateralDelta / outputAmount;

        callConfig.router.pluginTransfer(IERC20(outputToken), address(callConfig.positionStore), request.trader, traderAmountOut);
        // request.subaccount.depositToken(callConfig.router, request.collateralToken, traderAmountOut);
        // SafeERC20.safeTransferFrom(callConfig.depositCollateralToken, address(callConfig.puppetStore), subaccountAddress, request.collateralDelta);
    }

    function sendToken(Router router, IERC20 token, address from, address to, uint amount) internal returns (uint) {
        (bool success, bytes memory returndata) = address(token).call(abi.encodeCall(router.pluginTransfer, (token, from, to, amount)));

        if (success && returndata.length == 0 && abi.decode(returndata, (bool))) return amount;

        return 0;
    }

    error ExecutePosition__UnexpectedEventData();
    error ExecutePosition__MissingRequest(bytes32 positionKey, bytes32 key);
}
