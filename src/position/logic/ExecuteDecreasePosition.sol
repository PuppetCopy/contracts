// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IGmxEventUtils} from "./../interface/IGmxEventUtils.sol";

import {Router} from "src/utils/Router.sol";
import {GmxPositionUtils} from "../util/GmxPositionUtils.sol";
import {Precision} from "./../../utils/Precision.sol";

import {PuppetStore} from "../store/PuppetStore.sol";
import {PositionStore} from "../store/PositionStore.sol";

import {CugarStore} from "./../../shared/store/CugarStore.sol";
import {Cugar} from "../../shared/Cugar.sol";

library ExecuteDecreasePosition {
    event ExecuteDecreasePosition__DecreasePosition(
        bytes32 requestKey, bytes32 positionKey, uint totalAmountOut, uint profit, uint totalPerformanceFee, uint traderPerformanceCutoffFee
    );

    struct CallConfig {
        Router router;
        PositionStore positionStore;
        PuppetStore puppetStore;
        CugarStore cugarStore;
        Cugar cugar;
        address positionRouterAddress;
        address gmxOrderHandler;
        uint tokenTransferGasLimit;
        uint performanceFeeRate;
        uint traderPerformanceFeeShare;
    }

    struct CallParams {
        PositionStore.MirrorPosition mirrorPosition;
        IGmxEventUtils.EventLogData eventLogData;
        bytes32 positionKey;
        bytes32 requestKey;
        address positionRouterAddress;
        IERC20 outputToken;
        uint puppetListLength;
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

        uint totalAmountOut = eventLogData.uintItems.items[0].value;

        PositionStore.RequestAdjustment memory request = callConfig.positionStore.getRequestAdjustment(key);
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
            positionRouterAddress: address(callConfig.positionStore),
            outputToken: IERC20(eventLogData.addressItems.items[0].value),
            puppetListLength: mirrorPosition.puppetList.length,
            totalAmountOut: totalAmountOut,
            profit: profit
        });

        _decrease(callConfig, order, callParams, request);
    }

    function _decrease(
        CallConfig calldata callConfig,
        GmxPositionUtils.Props calldata order,
        CallParams memory callParams,
        PositionStore.RequestAdjustment memory request
    ) internal {
        callParams.mirrorPosition.collateral -= request.collateralDelta;
        callParams.mirrorPosition.size -= request.sizeDelta;
        callParams.mirrorPosition.cumulativeTransactionCost += request.transactionCost;

        uint[] memory feeAmountList = new uint[](callParams.puppetListLength);
        uint[] memory balanceList = callConfig.puppetStore.getBalanceList(callParams.outputToken, callParams.mirrorPosition.puppetList);
        uint totalPerformanceFee;
        uint traderPerformanceCutoffFee;

        for (uint i = 0; i < callParams.puppetListLength; i++) {
            if (request.puppetCollateralDeltaList[i] == 0) continue;

            uint collateralDelta = request.puppetCollateralDeltaList[i];

            callParams.mirrorPosition.collateralList[i] -= collateralDelta;

            (uint performanceFee, uint traderCutoff, uint amountOutAfterFee) = getDistribution(
                callConfig.performanceFeeRate,
                callConfig.traderPerformanceFeeShare,
                callParams.profit,
                collateralDelta * callParams.mirrorPosition.collateral / callParams.totalAmountOut,
                callParams.totalAmountOut
            );

            totalPerformanceFee += performanceFee;
            traderPerformanceCutoffFee += traderCutoff;

            feeAmountList[i] = performanceFee;
            balanceList[i] += amountOutAfterFee;
        }

        callConfig.puppetStore.setBalanceList(callParams.outputToken, callParams.mirrorPosition.puppetList, balanceList);
        callConfig.cugar.increaseCugarList(callConfig.cugarStore, callParams.outputToken, callParams.mirrorPosition.puppetList, feeAmountList);

        // https://github.com/gmx-io/gmx-synthetics/blob/main/contracts/position/DecreasePositionUtils.sol#L91
        if (callParams.mirrorPosition.size == order.numbers.sizeDeltaUsd) {
            callConfig.positionStore.removeMirrorPosition(callParams.positionKey);
        } else {
            callConfig.positionStore.setMirrorPosition(callParams.positionKey, callParams.mirrorPosition);
        }

        callConfig.positionStore.removeRequestDecrease(callParams.requestKey);

        if (request.collateralDelta > 0) {
            callConfig.cugar.increaseCugar(
                callConfig.cugarStore, callParams.outputToken, callParams.mirrorPosition.trader, traderPerformanceCutoffFee
            );

            SafeERC20.safeTransferFrom(
                callParams.outputToken,
                callConfig.positionRouterAddress,
                callParams.mirrorPosition.trader,
                request.collateralDelta * callParams.mirrorPosition.collateral / callParams.totalAmountOut
            );
        }

        emit ExecuteDecreasePosition__DecreasePosition(
            callParams.requestKey,
            callParams.positionKey,
            callParams.totalAmountOut,
            callParams.profit,
            totalPerformanceFee,
            traderPerformanceCutoffFee
        );
    }

    function getDistribution(uint performanceFeeRate, uint traderPerformanceFeeShare, uint totalProfit, uint amountOut, uint totalAmountOut)
        internal
        pure
        returns (uint performanceFee, uint traderPerformanceCutoffFee, uint amountOutAfterFee)
    {
        uint profit = totalProfit * amountOut / totalAmountOut;

        performanceFee = Precision.applyFactor(profit, performanceFeeRate);
        amountOutAfterFee = profit - performanceFee;

        traderPerformanceCutoffFee = Precision.applyFactor(performanceFee, traderPerformanceFeeShare);

        performanceFee -= traderPerformanceCutoffFee;

        return (performanceFee, traderPerformanceCutoffFee, amountOutAfterFee);
    }

    error ExecutePosition__InvalidRequest(bytes32 positionKey, bytes32 key);
    error ExecutePosition__UnexpectedEventData();
}
