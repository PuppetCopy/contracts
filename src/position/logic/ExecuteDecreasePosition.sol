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
import {PositionUtils} from "./../util/PositionUtils.sol";
import {UserGeneratedRevenue} from "../../shared/UserGeneratedRevenue.sol";

library ExecuteDecreasePosition {
    // event ExecuteDecreasePosition__FailedTransfer(bytes32 positionKey, bytes32 requestKey, address puppet, uint amount);

    struct CallConfig {
        Router router;
        PositionStore positionStore;
        PuppetStore puppetStore;
        UserGeneratedRevenue userGeneratedRevenue;
        address positionRouterAddress;
        address gmxOrderHandler;
        uint tokenTransferGasLimit;
        uint platformPerformanceFeeRate;
        uint traderPerformanceFeeShare;
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
            outputTokenAddress: outputTokenAddress,
            puppetStoreAddress: address(callConfig.puppetStore),
            outputToken: IERC20(outputTokenAddress),
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
        if (callParams.totalAmountOut > 0) {
            uint traderPerformanceFee;

            uint amountOutMultiplier = Precision.toFactor(order.numbers.initialCollateralDeltaAmount, callParams.totalAmountOut);

            for (uint i = 0; i < callParams.mirrorPosition.puppetList.length; i++) {
                if (request.puppetCollateralDeltaList[i] == 0) continue;

                uint collateralDelta = request.puppetCollateralDeltaList[i];
                uint amountOut = collateralDelta * callParams.mirrorPosition.collateral / callParams.totalAmountOut;
                uint amountOutAfterFee = amountOut - (callConfig.platformPerformanceFeeRate * amountOut / callParams.totalAmountOut);

                uint profitShare = callParams.profit * amountOut / callParams.totalAmountOut;

                callParams.mirrorPosition.collateralList[i] -= collateralDelta;

                SafeERC20.safeTransferFrom(callParams.outputToken, callParams.puppetStoreAddress, request.trader, amountOutAfterFee);
            }

            callConfig.router.transfer(
                callParams.outputToken,
                callParams.puppetStoreAddress,
                request.trader,
                order.numbers.initialCollateralDeltaAmount * request.collateralDelta / callParams.totalAmountOut
            );
        } else {
            for (uint i = 0; i < callParams.mirrorPosition.puppetList.length; i++) {
                uint collateralDelta = request.puppetCollateralDeltaList[i];

                callParams.mirrorPosition.collateralList[i] -= collateralDelta;
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

    error ExecutePosition__InvalidRequest(bytes32 positionKey, bytes32 key);
    error ExecutePosition__UnexpectedEventData();
}
