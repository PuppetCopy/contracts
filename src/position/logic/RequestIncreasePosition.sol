// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IGmxExchangeRouter} from "./../interface/IGmxExchangeRouter.sol";

import {Router} from "./../../utils/Router.sol";
import {Calc} from "./../../utils/Calc.sol";
import {IWNT} from "./../../utils/interfaces/IWNT.sol";
import {ErrorUtils} from "./../../utils/ErrorUtils.sol";
import {GmxPositionUtils} from "../util/GmxPositionUtils.sol";
import {PositionUtils} from "./../util/PositionUtils.sol";
import {TransferUtils} from "./../../utils/TransferUtils.sol";

import {Subaccount} from "./../../shared/Subaccount.sol";
import {SubaccountFactory} from "./../../shared/SubaccountFactory.sol";
import {SubaccountStore} from "./../../shared/store/SubaccountStore.sol";

import {PuppetStore} from "./../store/PuppetStore.sol";
import {PositionStore} from "../store/PositionStore.sol";

library RequestIncreasePosition {
    event RequestIncreasePosition__Match(address trader, address subaccount, bytes32 requestKey, address[] puppetList);
    event RequestIncreasePosition__Request(
        address trader,
        address subaccount,
        bytes32 requestKey,
        uint[] puppetCollateralDeltaList,
        uint sizeDelta,
        uint totalSizeDelta,
        uint collateralDelta,
        uint totalCollateralDelta,
        uint reducePuppetSizeDelta
    );
    event RequestIncreasePosition__RequestReducePuppetSize(
        address trader, address subaccount, bytes32 requestKey, bytes32 reduceRequestKey, uint sizeDelta
    );

    struct CallConfig {
        IWNT wnt;
        IGmxExchangeRouter gmxExchangeRouter;
        Router router;
        SubaccountFactory subaccountFactory;
        SubaccountStore subaccountStore;
        PositionStore positionStore;
        PuppetStore puppetStore;
        address positionRouterAddress;
        address gmxRouter;
        address gmxOrderVault;
        bytes32 referralCode;
        uint platformFee;
        uint callbackGasLimit;
        uint limitPuppetList;
        uint minSizeMatch;
        uint tokenTransferGasLimit;
    }

    struct TraderCallParams {
        address market;
        address collateralToken;
        bool isLong;
        uint executionFee;
        uint collateralDelta;
        uint sizeDelta;
        uint acceptablePrice;
        uint triggerPrice;
        address[] puppetList;
    }

    struct CallParams {
        PuppetStore.Rule[] ruleList;
        PositionStore.Activity[] activityList;
        IERC20 collateralToken;
        Subaccount subaccount;
        bytes32 routeKey;
        bytes32 positionKey;
        address subaccountAddress;
        address positionStoreAddress;
        uint reducePuppetSizeDelta;
        uint totalSizeDelta;
        uint totalCollateralDelta;
    }

    function increase(CallConfig memory callConfig, TraderCallParams calldata traderCallParams, address from) internal {
        bytes32 positionKey =
            GmxPositionUtils.getPositionKey(from, traderCallParams.market, traderCallParams.collateralToken, traderCallParams.isLong);

        PositionStore.MirrorPosition memory mirrorPosition = callConfig.positionStore.getMirrorPosition(positionKey);

        bytes32 routeKey = PositionUtils.getRouteKey(from, traderCallParams.collateralToken);
        PuppetStore.Rule[] memory ruleList = callConfig.puppetStore.getRuleList(routeKey, traderCallParams.puppetList);
        PositionStore.Activity[] memory activityList = callConfig.positionStore.getActivityList(routeKey, traderCallParams.puppetList);

        Subaccount subaccount = callConfig.subaccountStore.getSubaccount(from);

        if (address(subaccount) == address(0)) {
            subaccount = callConfig.subaccountFactory.createSubaccount(callConfig.subaccountStore, from);
        }

        RequestIncreasePosition.CallParams memory callParams = RequestIncreasePosition.CallParams({
            ruleList: ruleList,
            activityList: activityList,
            collateralToken: IERC20(traderCallParams.collateralToken),
            subaccount: subaccount,
            routeKey: routeKey,
            positionKey: positionKey,
            subaccountAddress: address(subaccount),
            positionStoreAddress: address(callConfig.positionStore),
            reducePuppetSizeDelta: 0,
            totalCollateralDelta: traderCallParams.collateralDelta,
            totalSizeDelta: traderCallParams.sizeDelta
        });

        PositionStore.RequestIncrease memory request = PositionStore.RequestIncrease({
            trader: from,
            puppetCollateralDeltaList: new uint[](traderCallParams.puppetList.length),
            leverageTarget: 0,
            collateralDelta: traderCallParams.collateralDelta,
            sizeDelta: traderCallParams.sizeDelta
        });

        if (mirrorPosition.size == 0) {
            request.leverageTarget = traderCallParams.sizeDelta * Calc.BASIS_POINT_DIVISOR / traderCallParams.collateralDelta;
            open(callConfig, callParams, request, traderCallParams);
        } else {
            request.leverageTarget = (mirrorPosition.size + traderCallParams.sizeDelta) * Calc.BASIS_POINT_DIVISOR
                / (mirrorPosition.collateral + traderCallParams.collateralDelta);

            adjust(callConfig, mirrorPosition, callParams, request, traderCallParams);
        }
    }

    function open(
        CallConfig memory callConfig,
        CallParams memory callParams,
        PositionStore.RequestIncrease memory request,
        TraderCallParams calldata traderCallParams
    ) internal returns (bytes32 requestKey) {
        if (traderCallParams.puppetList.length > callConfig.limitPuppetList) revert RequestIncreasePosition__PuppetListLimitExceeded();

        for (uint i = 0; i < traderCallParams.puppetList.length; i++) {
            PuppetStore.Rule memory rule = callParams.ruleList[i];
            PositionStore.Activity memory activity = callParams.activityList[i];

            if (
                rule.expiry < block.timestamp // rule expired or about to expire
                    || activity.latestFunding + rule.throttleActivity < block.timestamp // throttle in case of frequent matching
                    || activity.allowance <= rule.allowance // loss mitigation
            ) {
                continue;
            }

            uint allowedAmount = Math.min( // the lowest of either the allowance or the trader's deposit
                rule.allowance * rule.allowanceRate / Calc.BASIS_POINT_DIVISOR, // amount allowed by the rule
                traderCallParams.collateralDelta // trader own deposit
            );

            uint sizeDelta = allowedAmount * request.leverageTarget / Calc.BASIS_POINT_DIVISOR;

            if (sizeDelta < callConfig.minSizeMatch) {
                continue;
            }

            uint amountIn =
                sendTokenOptim(callConfig, callParams.collateralToken, traderCallParams.puppetList[i], callParams.positionStoreAddress, allowedAmount);

            uint amountAfterFee = amountIn - PositionUtils.getPlatformMatchingFee(callConfig.platformFee, sizeDelta);

            request.puppetCollateralDeltaList[i] = amountAfterFee;

            activity.latestFunding = block.timestamp;
            activity.allowance -= amountIn; // reduce allowance by the amount matched

            callParams.totalCollateralDelta += amountAfterFee;
            callParams.totalSizeDelta += amountAfterFee * request.leverageTarget / Calc.BASIS_POINT_DIVISOR;
            callParams.activityList[i] = activity;
        }

        callConfig.positionStore.setRuleActivityList(callParams.routeKey, traderCallParams.puppetList, callParams.activityList);
        callConfig.positionStore.setRequestIncreaseMap(callParams.positionKey, request);

        requestKey = _createOrder(callConfig, callParams, request, traderCallParams);

        emit RequestIncreasePosition__Match(request.trader, callParams.subaccountAddress, requestKey, traderCallParams.puppetList);
    }

    function adjust(
        CallConfig memory callConfig,
        PositionStore.MirrorPosition memory mirrorPosition,
        CallParams memory callParams,
        PositionStore.RequestIncrease memory request,
        TraderCallParams calldata traderCallParams
    ) internal returns (bytes32 requestKey) {
        if (traderCallParams.puppetList.length > callConfig.limitPuppetList) {
            revert RequestIncreasePosition__PuppetListLimitExceeded();
        }

        for (uint i = 0; i < mirrorPosition.puppetList.length; i++) {
            PuppetStore.Rule memory rule = callParams.ruleList[i];
            PositionStore.Activity memory activity = callParams.activityList[i];

            uint desiredAmountIn = traderCallParams.sizeDelta / mirrorPosition.puppetDepositList[i];

            // puppet's rule and activtiy applied per trader
            uint amountIn = rule.expiry < block.timestamp // filter out frequent deposit activity. defined during rule setup
                || activity.latestFunding + rule.throttleActivity < block.timestamp // expired rule. acounted every increase deposit
                || activity.allowance <= rule.allowance // stop loss. accounted every reduce adjustment
                || desiredAmountIn == 0 // did not match initial deposit
                ? 0
                : sendTokenOptim(callConfig, callParams.collateralToken, mirrorPosition.puppetList[i], callParams.positionStoreAddress, desiredAmountIn);

            uint sizeDelta = traderCallParams.sizeDelta * desiredAmountIn / mirrorPosition.size;

            if (amountIn > 0) {
                uint amountAfterFee = amountIn - PositionUtils.getPlatformMatchingFee(callConfig.platformFee, sizeDelta);

                request.puppetCollateralDeltaList[i] += amountAfterFee;
                callParams.totalSizeDelta += sizeDelta;
                callParams.totalCollateralDelta += amountAfterFee;

                activity.latestFunding = block.timestamp;
                callParams.activityList[i] = activity;
            } else {
                uint adjustedSizeDelta = sizeDelta * Calc.diff(request.leverageTarget, mirrorPosition.leverage) / mirrorPosition.leverage;
                if (request.leverageTarget > mirrorPosition.leverage) {
                    callParams.totalSizeDelta += adjustedSizeDelta;
                } else {
                    callParams.reducePuppetSizeDelta += adjustedSizeDelta;
                }
            }
        }

        callConfig.positionStore.setRuleActivityList(callParams.routeKey, mirrorPosition.puppetList, callParams.activityList);
        callConfig.positionStore.setRequestIncreaseMap(callParams.positionKey, request);

        if (callParams.totalSizeDelta > callParams.reducePuppetSizeDelta) {
            requestKey = _createOrder(callConfig, callParams, request, traderCallParams);
        } else {
            callParams.totalSizeDelta = 0;
            callParams.reducePuppetSizeDelta = callParams.reducePuppetSizeDelta;
            // callConfig.positionStore.setRequestReduceTargetLeverageMap(callParams.positionKey, request);
            bytes32 key = _reducePuppetSizeDelta(callConfig, callParams, traderCallParams);
            requestKey = _createOrder(callConfig, callParams, request, traderCallParams);

            emit RequestIncreasePosition__RequestReducePuppetSize(
                request.trader, callParams.subaccountAddress, requestKey, key, callParams.reducePuppetSizeDelta
            );
        }
    }

    function _createOrder(
        CallConfig memory callConfig, //
        CallParams memory callParams,
        PositionStore.RequestIncrease memory request,
        TraderCallParams calldata traderCallParams
    ) internal returns (bytes32 requestKey) {
        GmxPositionUtils.CreateOrderParams memory orderParams = GmxPositionUtils.CreateOrderParams({
            addresses: GmxPositionUtils.CreateOrderParamsAddresses({
                receiver: callParams.positionStoreAddress,
                callbackContract: callConfig.positionRouterAddress,
                uiFeeReceiver: address(0),
                market: traderCallParams.market,
                initialCollateralToken: traderCallParams.collateralToken,
                swapPath: new address[](0) // swapPath
            }),
            numbers: GmxPositionUtils.CreateOrderParamsNumbers({
                initialCollateralDeltaAmount: callParams.totalCollateralDelta,
                sizeDeltaUsd: callParams.totalSizeDelta,
                triggerPrice: traderCallParams.triggerPrice,
                acceptablePrice: traderCallParams.acceptablePrice,
                executionFee: traderCallParams.executionFee,
                callbackGasLimit: callConfig.callbackGasLimit,
                minOutputAmount: 0
            }),
            orderType: GmxPositionUtils.OrderType.MarketIncrease,
            decreasePositionSwapType: GmxPositionUtils.DecreasePositionSwapType.NoSwap,
            isLong: traderCallParams.isLong,
            shouldUnwrapNativeToken: false,
            referralCode: callConfig.referralCode
        });

        // native ETH identified by depositing more than the execution fee
        if (traderCallParams.collateralToken == address(callConfig.wnt) && traderCallParams.executionFee > msg.value) {
            TransferUtils.depositAndSendWnt(
                callConfig.wnt,
                callParams.positionStoreAddress,
                callConfig.tokenTransferGasLimit,
                callConfig.gmxOrderVault,
                traderCallParams.executionFee + traderCallParams.collateralDelta
            );
        } else {
            TransferUtils.depositAndSendWnt(
                callConfig.wnt,
                callParams.positionStoreAddress,
                callConfig.tokenTransferGasLimit,
                callConfig.gmxOrderVault,
                traderCallParams.executionFee
            );
            callConfig.router.transfer(callParams.collateralToken, request.trader, callConfig.gmxOrderVault, traderCallParams.collateralDelta);
        }

        callParams.subaccount.execute(
            address(callParams.collateralToken),
            abi.encodeWithSelector(callParams.collateralToken.approve.selector, callConfig.gmxRouter, traderCallParams.collateralDelta)
        );

        (bool orderSuccess, bytes memory orderReturnData) = callParams.subaccount.execute(
            address(callConfig.gmxExchangeRouter), abi.encodeWithSelector(callConfig.gmxExchangeRouter.createOrder.selector, orderParams)
        );

        if (!orderSuccess) ErrorUtils.revertWithParsedMessage(orderReturnData);

        requestKey = abi.decode(orderReturnData, (bytes32));

        emit RequestIncreasePosition__Request(
            request.trader,
            callParams.subaccountAddress,
            requestKey,
            request.puppetCollateralDeltaList,
            request.sizeDelta,
            callParams.totalSizeDelta,
            request.collateralDelta,
            callParams.totalCollateralDelta,
            callParams.reducePuppetSizeDelta
        );
    }

    function _reducePuppetSizeDelta(
        CallConfig memory callConfig, //
        CallParams memory callParams,
        TraderCallParams calldata traderCallparams
    ) internal returns (bytes32 requestKey) {
        GmxPositionUtils.CreateOrderParams memory params = GmxPositionUtils.CreateOrderParams({
            addresses: GmxPositionUtils.CreateOrderParamsAddresses({
                receiver: callParams.positionStoreAddress,
                callbackContract: callConfig.positionRouterAddress,
                uiFeeReceiver: address(0),
                market: traderCallparams.market,
                initialCollateralToken: traderCallparams.collateralToken,
                swapPath: new address[](0) // swapPath
            }),
            numbers: GmxPositionUtils.CreateOrderParamsNumbers({
                initialCollateralDeltaAmount: 0,
                sizeDeltaUsd: callParams.reducePuppetSizeDelta,
                triggerPrice: traderCallparams.triggerPrice,
                acceptablePrice: traderCallparams.acceptablePrice,
                executionFee: traderCallparams.executionFee,
                callbackGasLimit: callConfig.callbackGasLimit,
                minOutputAmount: 0
            }),
            orderType: GmxPositionUtils.OrderType.MarketDecrease,
            decreasePositionSwapType: GmxPositionUtils.DecreasePositionSwapType.NoSwap,
            isLong: traderCallparams.isLong,
            shouldUnwrapNativeToken: false,
            referralCode: callConfig.referralCode
        });

        (bool orderSuccess, bytes memory orderReturnData) = callParams.subaccount.execute(
            address(callConfig.gmxExchangeRouter), abi.encodeWithSelector(callConfig.gmxExchangeRouter.createOrder.selector, params)
        );
        if (!orderSuccess) ErrorUtils.revertWithParsedMessage(orderReturnData);

        requestKey = abi.decode(orderReturnData, (bytes32));
    }

    // non reverting token transfer, return amount transferred
    function sendTokenOptim(CallConfig memory callConfig, IERC20 token, address from, address to, uint amount) internal returns (uint) {
        (bool success, bytes memory returndata) = callConfig.router.rawTrasnfer{gas: callConfig.tokenTransferGasLimit}(token, from, to, amount);

        if (success && returndata.length == 0 && abi.decode(returndata, (bool))) return amount;

        return 0;
    }

    error RequestIncreasePosition__PuppetListLimitExceeded();
    error RequestIncreasePosition__AddressListLengthMismatch();
}
