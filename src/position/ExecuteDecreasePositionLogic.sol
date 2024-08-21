// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {IGmxEventUtils} from "./interface/IGmxEventUtils.sol";
import {Router} from "src/shared/Router.sol";

import {CoreContract} from "../utils/CoreContract.sol";
import {EventEmitter} from "../utils/EventEmitter.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {Precision} from "./../utils/Precision.sol";
import {GmxPositionUtils} from "./utils/GmxPositionUtils.sol";

import {PuppetStore} from "../puppet/store/PuppetStore.sol";
import {RevenueStore} from "../tokenomics/store/RevenueStore.sol";
import {PositionStore} from "./store/PositionStore.sol";

contract ExecuteDecreasePositionLogic is CoreContract {
    event ExecuteDecreasePositionLogic__SetConfig(uint timestamp, Config config);

    struct Config {
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

    Config config;

    constructor(
        IAuthority _authority,
        EventEmitter _eventEmitter,
        Config memory _config
    ) CoreContract("ExecuteDecreasePositionLogic", "1", _authority, _eventEmitter) {
        _setConfig(_config);
    }

    function execute(
        bytes32 requestKey,
        GmxPositionUtils.Props calldata order,
        bytes calldata eventData
    ) external auth {
        (IGmxEventUtils.EventLogData memory eventLogData) = abi.decode(eventData, (IGmxEventUtils.EventLogData));

        // Check if there is at least one uint item available
        if (eventLogData.uintItems.items.length == 0 && eventLogData.uintItems.arrayItems.length == 0) {
            revert ExecuteDecreasePositionLogic__UnexpectedEventData();
        }

        CallParams memory callParams = CallParams({
            totalAmountOut: eventLogData.uintItems.items[0].value, //
            totalPerformanceFee: 0,
            traderPerformanceCutoffFee: 0,
            profit: 0
        });

        PositionStore.RequestAdjustment memory request = config.positionStore.getRequestAdjustment(requestKey);
        PositionStore.MirrorPosition memory mirrorPosition = config.positionStore.getMirrorPosition(request.positionKey);

        if (mirrorPosition.size == 0) {
            revert ExecuteDecreasePositionLogic__InvalidRequest(request.positionKey, requestKey);
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
                config.performanceFeeRate,
                config.traderPerformanceFeeShare,
                callParams.profit,
                request.collateralDeltaList[i] * mirrorPosition.collateral / callParams.profit,
                callParams.profit
            );

            callParams.totalPerformanceFee += performanceFee;
            callParams.traderPerformanceCutoffFee += traderCutoff;

            contributionList[i] = performanceFee;
            outputAmountList[i] += amountOutAfterFee;
        }

        config.puppetStore.increaseBalanceList(outputToken, address(this), mirrorPosition.puppetList, outputAmountList);

        if (callParams.profit > 0) {
            config.revenueStore.commitRewardList(
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
            config.positionStore.removeMirrorPosition(request.positionKey);
        } else {
            config.positionStore.setMirrorPosition(request.positionKey, mirrorPosition);
        }

        config.positionStore.removeRequestDecrease(requestKey);

        if (request.collateralDelta > 0) {
            config.router.transfer(
                outputToken,
                config.gmxOrderReciever,
                mirrorPosition.trader,
                request.collateralDelta * mirrorPosition.collateral / callParams.totalAmountOut
            );
        }

        eventEmitter.log(
            "ExecuteDecreasePositionLogic",
            abi.encode(
                requestKey,
                request.positionKey,
                callParams.totalAmountOut,
                callParams.profit,
                callParams.totalPerformanceFee,
                callParams.traderPerformanceCutoffFee
            )
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

    function setConfig(Config memory _config) external auth {
        _setConfig(_config);
    }

    function _setConfig(Config memory _config) internal {
        config = _config;

        emit ExecuteDecreasePositionLogic__SetConfig(block.timestamp, _config);
    }

    error ExecuteDecreasePositionLogic__InvalidRequest(bytes32 positionKey, bytes32 key);
    error ExecuteDecreasePositionLogic__UnexpectedEventData();
}
