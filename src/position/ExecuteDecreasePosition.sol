// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {Permission} from "../utils/access/Permission.sol";

import {IGmxEventUtils} from "./interface/IGmxEventUtils.sol";

import {Router} from "src/shared/Router.sol";
import {GmxPositionUtils} from "./utils/GmxPositionUtils.sol";
import {Precision} from "./../utils/Precision.sol";

import {PuppetStore} from "./../puppet/store/PuppetStore.sol";
import {PositionStore} from "./store/PositionStore.sol";
import {RevenueStore} from "./../tokenomics/store/RevenueStore.sol";

contract ExecuteDecreasePosition is Permission, EIP712 {
    event ExecuteDecreasePosition__SetConfig(uint timestamp, CallConfig callConfig);

    event ExecuteDecreasePosition__Execute(
        bytes32 requestKey, uint totalAmountOut, uint profit, uint totalPerformanceFee, uint traderPerformanceCutoffFee
    );

    struct CallConfig {
        Router router;
        PositionStore positionStore;
        PuppetStore puppetStore;
        RevenueStore revenueStore;
        address gmxOrderReciever;
        uint performanceFeeRate;
        uint traderPerformanceFeeShare;
    }

    struct CallParams {
        uint totalAmountOut;
        uint profit;
        uint totalPerformanceFee;
        uint traderPerformanceCutoffFee;
    }

    CallConfig callConfig;

    constructor(IAuthority _authority, CallConfig memory _callConfig) Permission(_authority) EIP712("ExecuteDecreasePosition", "1") {
        _setConfig(_callConfig);
    }

    function execute(bytes32 requestKey, GmxPositionUtils.Props calldata order, bytes calldata eventData) external auth {
        (IGmxEventUtils.EventLogData memory eventLogData) = abi.decode(eventData, (IGmxEventUtils.EventLogData));

        // Check if there is at least one uint item available
        if (eventLogData.uintItems.items.length == 0 && eventLogData.uintItems.arrayItems.length == 0) {
            revert ExecutePosition__UnexpectedEventData();
        }

        CallParams memory callParams = CallParams({
            totalAmountOut: eventLogData.uintItems.items[0].value, //
            totalPerformanceFee: 0,
            traderPerformanceCutoffFee: 0,
            profit: 0
        });

        PositionStore.RequestAdjustment memory request = callConfig.positionStore.getRequestAdjustment(requestKey);
        PositionStore.MirrorPosition memory mirrorPosition = callConfig.positionStore.getMirrorPosition(request.positionKey);

        if (mirrorPosition.size == 0) {
            revert ExecutePosition__InvalidRequest(request.positionKey, requestKey);
        }
        IERC20 outputToken = IERC20(eventLogData.addressItems.items[0].value);

        if (callParams.totalAmountOut > order.numbers.initialCollateralDeltaAmount) {
            callParams.profit = callParams.totalAmountOut - order.numbers.initialCollateralDeltaAmount;
        }

        mirrorPosition.collateral -= request.collateralDelta;
        mirrorPosition.size -= request.sizeDelta;
        mirrorPosition.cumulativeTransactionCost += request.transactionCost;

        uint[] memory outputAmountList = new uint[](mirrorPosition.puppetList.length);
        uint[] memory contributionList = new uint[](mirrorPosition.puppetList.length);

        for (uint i = 0; i < mirrorPosition.puppetList.length; i++) {
            if (request.collateralDeltaList[i] == 0) continue;

            mirrorPosition.collateralList[i] -= request.collateralDeltaList[i];

            (uint performanceFee, uint traderCutoff, uint amountOutAfterFee) = getDistribution(
                callConfig.performanceFeeRate,
                callConfig.traderPerformanceFeeShare,
                callParams.profit,
                request.collateralDeltaList[i] * mirrorPosition.collateral / callParams.profit,
                callParams.profit
            );

            callParams.totalPerformanceFee += performanceFee;
            callParams.traderPerformanceCutoffFee += traderCutoff;

            contributionList[i] = performanceFee;
            outputAmountList[i] += amountOutAfterFee;
        }

        callConfig.puppetStore.increaseBalanceList(outputToken, address(this), mirrorPosition.puppetList, outputAmountList);

        if (callParams.profit > 0) {
            callConfig.revenueStore.commitRewardList(
                outputToken, //
                address(this),
                mirrorPosition.puppetList,
                contributionList,
                mirrorPosition.trader,
                callParams.totalPerformanceFee
            );
        }

        // https://github.com/gmx-io/gmx-synthetics/blob/main/contracts/position/DecreasePositionUtils.sol#L91
        if (mirrorPosition.size == order.numbers.sizeDeltaUsd) {
            callConfig.positionStore.removeMirrorPosition(request.positionKey);
        } else {
            callConfig.positionStore.setMirrorPosition(request.positionKey, mirrorPosition);
        }

        callConfig.positionStore.removeRequestDecrease(requestKey);

        if (request.collateralDelta > 0) {
            callConfig.router.transfer(
                outputToken,
                callConfig.gmxOrderReciever,
                mirrorPosition.trader,
                request.collateralDelta * mirrorPosition.collateral / callParams.totalAmountOut
            );
        }

        emit ExecuteDecreasePosition__Execute(
            requestKey, callParams.totalAmountOut, callParams.profit, callParams.totalPerformanceFee, callParams.traderPerformanceCutoffFee
        );
    }

    function getDistribution(
        uint performanceFeeRate, //
        uint traderPerformanceFeeShare,
        uint totalProfit,
        uint amountOut,
        uint totalAmountOut
    ) internal pure returns (uint performanceFee, uint traderPerformanceCutoffFee, uint amountOutAfterFee) {
        uint profit = totalProfit * amountOut / totalAmountOut;

        performanceFee = Precision.applyFactor(performanceFeeRate, profit);
        amountOutAfterFee = profit - performanceFee;

        traderPerformanceCutoffFee = Precision.applyFactor(traderPerformanceFeeShare, performanceFee);

        performanceFee -= traderPerformanceCutoffFee;

        return (performanceFee, traderPerformanceCutoffFee, amountOutAfterFee);
    }

    // governance

    function setConfig(CallConfig memory _callConfig) external auth {
        _setConfig(_callConfig);
    }

    function _setConfig(CallConfig memory _callConfig) internal {
        callConfig = _callConfig;

        emit ExecuteDecreasePosition__SetConfig(block.timestamp, callConfig);
    }

    error ExecutePosition__InvalidRequest(bytes32 positionKey, bytes32 key);
    error ExecutePosition__UnexpectedEventData();
}
