// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IGmxEventUtils} from "./../interface/IGmxEventUtils.sol";

import {Router} from "src/utils/Router.sol";
import {GmxPositionUtils} from "../util/GmxPositionUtils.sol";

import {PuppetStore} from "../store/PuppetStore.sol";
import {PositionStore} from "../store/PositionStore.sol";
import {PuppetLogic} from "./../PuppetLogic.sol";

library ExecutePosition {
    struct CallConfig {
        Router router;
        PositionStore positionStore;
        PuppetStore puppetStore;
        PuppetLogic puppetLogic;
        address gmxOrderHandler;
    }

    function increase(CallConfig calldata callConfig, bytes32 key, GmxPositionUtils.Props calldata order) external {
        bytes32 positionKey = GmxPositionUtils.getPositionKey(
            order.addresses.account, order.addresses.market, order.addresses.initialCollateralToken, order.flags.isLong
        );

        PositionStore.RequestAdjustment memory request = callConfig.positionStore.getPendingRequestMap(key);
        PositionStore.MirrorPosition memory mirrorPosition = callConfig.positionStore.getMirrorPosition(positionKey);

        mirrorPosition.collateral += request.collateralDelta;
        mirrorPosition.size += request.sizeDelta;

        callConfig.positionStore.removePendingRequestMap(key);
        callConfig.positionStore.setMirrorPosition(key, mirrorPosition);
    }

    function decrease(CallConfig calldata callConfig, bytes32 key, GmxPositionUtils.Props calldata order, bytes calldata eventData) external {
        (IGmxEventUtils.EventLogData memory eventLogData) = abi.decode(eventData, (IGmxEventUtils.EventLogData));

        // Check if there is at least one uint item available
        if (eventLogData.uintItems.items.length == 0 && eventLogData.uintItems.arrayItems.length == 0) {
            revert ExecutePosition__UnexpectedEventData();
        }

        bytes32 positionKey = GmxPositionUtils.getPositionKey(
            order.addresses.account, order.addresses.market, order.addresses.initialCollateralToken, order.flags.isLong
        );
        PositionStore.RequestAdjustment memory request = callConfig.positionStore.getPendingRequestMap(key);
        PositionStore.MirrorPosition memory mirrorPosition = callConfig.positionStore.getMirrorPosition(positionKey);

        if (request.targetLeverage == 0 || mirrorPosition.size == 0) revert ExecutePosition__InvalidRequest(positionKey, key);

        mirrorPosition.collateral -= order.numbers.initialCollateralDeltaAmount;
        mirrorPosition.size -= order.numbers.sizeDeltaUsd;

        IERC20 outputToken = IERC20(eventLogData.addressItems.items[0].value);
        uint totalAmountOut = eventLogData.uintItems.items[0].value;

        processPuppetList(callConfig, request, mirrorPosition, outputToken, totalAmountOut);

        callConfig.positionStore.removePendingRequestMap(positionKey);

        callConfig.router.pluginTransfer(
            outputToken, address(callConfig.positionStore), request.trader, mirrorPosition.collateral * request.collateralDelta / totalAmountOut
        );
    }

    // Extracted function to process puppet activities
    function processPuppetList(
        CallConfig memory callConfig,
        PositionStore.RequestAdjustment memory request,
        PositionStore.MirrorPosition memory mirrorPosition,
        IERC20 outputToken,
        uint totalAmountOut
    ) internal {
        PuppetStore.Activity[] memory activityList = callConfig.puppetStore.getActivityList(request.routeKey, mirrorPosition.puppetList);

        for (uint i = 0; i < mirrorPosition.puppetList.length; i++) {
            PuppetStore.Activity memory activity = activityList[i];

            uint collateralDelta = request.puppetCollateralDeltaList[i];
            uint amountOut = mirrorPosition.collateral * mirrorPosition.puppetDepositList[i] / totalAmountOut;

            request.puppetCollateralDeltaList[i] -= collateralDelta;
            request.collateralDelta -= collateralDelta;
            request.sizeDelta -= request.sizeDelta * collateralDelta / mirrorPosition.size;

            activity.allowance += amountOut;
            activityList[i] = activity;

            sendTokenOptim(callConfig.router, outputToken, address(callConfig.positionStore), mirrorPosition.puppetList[i], amountOut);
        }

        callConfig.puppetLogic.setRouteActivityList(callConfig.puppetStore, request.routeKey, mirrorPosition.puppetList, activityList);
    }

    // optimistically send token, 0 allocated if failed
    function sendTokenOptim(Router router, IERC20 token, address from, address to, uint amount) internal returns (uint) {
        (bool success, bytes memory returndata) = address(token).call(abi.encodeCall(router.pluginTransfer, (token, from, to, amount)));

        if (success && returndata.length == 0 && abi.decode(returndata, (bool))) return amount;

        return 0;
    }

    error ExecutePosition__UnexpectedEventData();
    error ExecutePosition__InvalidRequest(bytes32 positionKey, bytes32 key);
}
