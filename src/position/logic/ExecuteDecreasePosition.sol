// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IGmxEventUtils} from "./../interface/IGmxEventUtils.sol";
import {Precision} from "./../../utils/Precision.sol";

import {Router} from "src/utils/Router.sol";
import {GmxPositionUtils} from "../util/GmxPositionUtils.sol";

import {PuppetStore} from "../store/PuppetStore.sol";
import {PositionStore} from "../store/PositionStore.sol";
import {PositionUtils} from "./../util/PositionUtils.sol";
import {UserGeneratedRevenue} from "../../shared/UserGeneratedRevenue.sol";

library ExecuteDecreasePosition {
    struct CallConfig {
        Router router;
        PositionStore positionStore;
        PuppetStore puppetStore;
        UserGeneratedRevenue userGeneratedRevenue;
        address gmxOrderHandler;
        uint profitFeeRate;
        uint traderProfitFeeCutoffRate;
    }

    struct CallParams {
        PositionStore.MirrorPosition mirrorPosition;
        IGmxEventUtils.EventLogData eventLogData;
        bytes32 positionKey;
        bytes32 requestKey;
        IERC20 outputTokenAddress;
        address puppetStoreAddress;
        IERC20 outputToken;
        uint totalAmountOut;
        uint profit;
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

        IERC20 outputTokenAddress = IERC20(eventLogData.addressItems.items[0].value);
        uint totalAmountOut = eventLogData.uintItems.items[0].value;

        PositionStore.RequestDecrease memory request = callConfig.positionStore.getRequestDecrease(key);
        PositionStore.MirrorPosition memory mirrorPosition = callConfig.positionStore.getMirrorPosition(positionKey);

        if (mirrorPosition.size == 0) {
            revert ExecutePosition__InvalidRequest(positionKey, key);
        }

        uint profit;

        if (totalAmountOut > order.numbers.initialCollateralDeltaAmount) {
            profit = totalAmountOut - order.numbers.initialCollateralDeltaAmount;
        }

        CallParams memory callParams = CallParams({
            mirrorPosition: mirrorPosition,
            eventLogData: eventLogData,
            positionKey: positionKey,
            requestKey: key,
            outputTokenAddress: outputTokenAddress,
            puppetStoreAddress: address(callConfig.puppetStore),
            outputToken: IERC20(outputTokenAddress),
            totalAmountOut: totalAmountOut,
            profit: profit
        });

        _decrease(callConfig, order, callParams, request);

        // emit ExecuteDecreasePosition__DecreasePosition(
        //     positionKey,
        //     key,
        //     order.addresses.account,
        //     order.addresses.market,
        //     order.addresses.initialCollateralToken,
        //     order.flags.isLong,
        //     order.numbers.sizeDeltaUsd,
        //     order.numbers.initialCollateralDeltaAmount,
        //     totalAmountOut,
        //     profit
        // );
    }

    function _decrease(
        CallConfig calldata callConfig,
        GmxPositionUtils.Props calldata order,
        CallParams memory callParams,
        PositionStore.RequestDecrease memory request
    ) internal {
        if (callParams.totalAmountOut > 0) {
            bytes32[] memory keyList = new bytes32[](callParams.mirrorPosition.puppetList.length);

            for (uint i = 0; i < callParams.mirrorPosition.puppetList.length; i++) {
                keyList[i] = PositionUtils.getRuleKey(callParams.outputTokenAddress, callParams.mirrorPosition.puppetList[i], request.trader);
            }

            uint[] memory activityList = callConfig.puppetStore.getActivityList(keyList);

            (uint traderFeeCutoff, uint puppetFee) = PositionUtils.getPlatformProfitDistribution(
                callConfig.profitFeeRate, callConfig.traderProfitFeeCutoffRate, order.numbers.initialCollateralDeltaAmount, callParams.totalAmountOut
            );

            for (uint i = 0; i < callParams.mirrorPosition.puppetList.length; i++) {
                uint collateralDelta = request.puppetCollateralDeltaList[i];
                uint amountOut = collateralDelta * callParams.mirrorPosition.collateral / callParams.totalAmountOut;
                uint amountOutAfterFee = amountOut - (puppetFee * amountOut / callParams.totalAmountOut);

                activityList[i] = activityList[i];

                if (callParams.profit > 0) {
                    uint profitShare = callParams.profit * amountOut / callParams.totalAmountOut;
                }

                callParams.mirrorPosition.puppetDepositList[i] -= collateralDelta;

                sendTokenOptim(
                    callConfig.router,
                    callParams.outputToken,
                    callParams.puppetStoreAddress,
                    callParams.mirrorPosition.puppetList[i],
                    amountOutAfterFee
                );
            }

            callConfig.puppetStore.setActivityList(keyList, activityList);

            callConfig.router.transfer(
                callParams.outputToken,
                callParams.puppetStoreAddress,
                request.trader,
                order.numbers.initialCollateralDeltaAmount * request.collateralDelta / callParams.totalAmountOut
            );
        } else {
            for (uint i = 0; i < callParams.mirrorPosition.puppetList.length; i++) {
                uint collateralDelta = request.puppetCollateralDeltaList[i];

                callParams.mirrorPosition.puppetDepositList[i] -= collateralDelta;
            }
        }

        // https://github.com/gmx-io/gmx-synthetics/blob/main/contracts/position/DecreasePositionUtils.sol#L91
        if (callParams.mirrorPosition.size == order.numbers.sizeDeltaUsd) {
            callConfig.positionStore.removeMirrorPosition(callParams.positionKey);
        } else {
            callParams.mirrorPosition.size -= order.numbers.sizeDeltaUsd; // fix
            callParams.mirrorPosition.collateral -= order.numbers.initialCollateralDeltaAmount;

            callConfig.positionStore.setMirrorPosition(callParams.positionKey, callParams.mirrorPosition);
        }

        callConfig.positionStore.removeRequestDecrease(callParams.requestKey);
    }

    // optimistically send token
    function sendTokenOptim(Router router, IERC20 token, address from, address to, uint amount) internal returns (bool) {
        (bool success, bytes memory returndata) = address(token).call(abi.encodeCall(router.transfer, (token, from, to, amount)));

        return success && returndata.length == 0 && abi.decode(returndata, (bool));
    }

    error ExecutePosition__InvalidRequest(bytes32 positionKey, bytes32 key);
    error ExecutePosition__UnexpectedEventData();
}
