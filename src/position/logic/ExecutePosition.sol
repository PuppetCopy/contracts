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
import {PuppetUtils} from "./../util/PuppetUtils.sol";

library ExecutePosition {
    struct CallConfig {
        Router router;
        PositionStore positionStore;
        PuppetStore puppetStore;
        PuppetLogic puppetLogic;
        address gmxOrderHandler;
    }

    struct CallParams {
        PositionStore.MirrorPosition mirrorPosition;
        IGmxEventUtils.EventLogData eventLogData;
        bytes32 positionKey;
        bytes32 requestKey;
        bytes32 routeKey;
        address outputTokenAddress;
        address puppetStoreAddress;
        IERC20 outputToken;
        uint totalAmountOut;
    }

    function increase(CallConfig calldata callConfig, bytes32 key, GmxPositionUtils.Props calldata order) internal {
        bytes32 positionKey = GmxPositionUtils.getPositionKey(
            order.addresses.account, order.addresses.market, order.addresses.initialCollateralToken, order.flags.isLong
        );

        PositionStore.RequestIncrease memory request = callConfig.positionStore.getRequestIncreaseMap(key);
        PositionStore.MirrorPosition memory mirrorPosition = callConfig.positionStore.getMirrorPosition(positionKey);

        mirrorPosition.collateral += request.collateralDelta;
        mirrorPosition.totalCollateral += order.numbers.initialCollateralDeltaAmount;
        mirrorPosition.size += request.sizeDelta;
        mirrorPosition.totalSize += order.numbers.sizeDeltaUsd;

        callConfig.positionStore.setMirrorPosition(key, mirrorPosition);
        callConfig.positionStore.removeRequestIncreaseMap(key);
    }

    function decrease(ExecutePosition.CallConfig calldata callConfig, bytes32 key, GmxPositionUtils.Props calldata order, bytes calldata eventData)
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
        bytes32 routeKey = PuppetUtils.getRouteKey(order.addresses.account, order.addresses.initialCollateralToken);

        address outputTokenAddress = eventLogData.addressItems.items[0].value;
        uint totalAmountOut = eventLogData.uintItems.items[0].value;

        PositionStore.RequestDecrease memory request = callConfig.positionStore.getRequestDecreaseMap(key);
        PositionStore.MirrorPosition memory mirrorPosition = callConfig.positionStore.getMirrorPosition(positionKey);

        if (mirrorPosition.size == 0) {
            revert ExecutePosition__InvalidRequest(positionKey, key);
        }

        ExecutePosition.CallParams memory callParams = ExecutePosition.CallParams({
            mirrorPosition: mirrorPosition,
            eventLogData: eventLogData,
            positionKey: positionKey,
            requestKey: key,
            routeKey: routeKey,
            outputTokenAddress: outputTokenAddress,
            puppetStoreAddress: address(callConfig.puppetStore),
            outputToken: IERC20(outputTokenAddress),
            totalAmountOut: totalAmountOut
        });

        _decrease(callConfig, order, callParams, request);
    }

    function _decrease(
        CallConfig calldata callConfig,
        GmxPositionUtils.Props calldata order,
        CallParams memory callParams,
        PositionStore.RequestDecrease memory request
    ) internal {
        callParams.mirrorPosition.collateral -= order.numbers.initialCollateralDeltaAmount;
        callParams.mirrorPosition.size -= order.numbers.sizeDeltaUsd;

        PuppetStore.Activity[] memory activityList = callConfig.puppetStore.getActivityList(callParams.routeKey, callParams.mirrorPosition.puppetList);

        for (uint i = 0; i < callParams.mirrorPosition.puppetList.length; i++) {
            PuppetStore.Activity memory activity = activityList[i];

            uint collateralDelta = request.puppetCollateralDeltaList[i];
            uint amountOut = callParams.mirrorPosition.totalCollateral * collateralDelta / callParams.totalAmountOut;

            callParams.mirrorPosition.puppetDepositList[i] -= collateralDelta;

            activity.allowance += amountOut;
            activityList[i] = activity;

            sendTokenOptim(
                callConfig.router, callParams.outputToken, callParams.puppetStoreAddress, callParams.mirrorPosition.puppetList[i], amountOut
            );
        }

        callConfig.positionStore.removeRequestIncreaseMap(callParams.requestKey);
        callConfig.positionStore.setMirrorPosition(callParams.positionKey, callParams.mirrorPosition);

        callConfig.puppetLogic.setRouteActivityList(callConfig.puppetStore, callParams.routeKey, callParams.mirrorPosition.puppetList, activityList);

        callConfig.router.pluginTransfer(
            callParams.outputToken,
            callParams.puppetStoreAddress,
            request.trader,
            callParams.mirrorPosition.collateral * request.collateralDelta / callParams.totalAmountOut
        );
    }

    // optimistically send token, 0 allocated if failed
    function sendTokenOptim(Router router, IERC20 token, address from, address to, uint amount) internal returns (bool) {
        (bool success, bytes memory returndata) = address(token).call(abi.encodeCall(router.pluginTransfer, (token, from, to, amount)));

        return success && returndata.length == 0 && abi.decode(returndata, (bool));
    }

    error ExecutePosition__InvalidRequest(bytes32 positionKey, bytes32 key);
    error ExecutePosition__UnexpectedEventData();
}
