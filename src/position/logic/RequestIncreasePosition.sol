// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IGmxExchangeRouter} from "./../interface/IGmxExchangeRouter.sol";

import {Router} from "./../../utils/Router.sol";
import {Calc} from "./../../utils/Calc.sol";
import {IWNT} from "./../../utils/interfaces/IWNT.sol";
import {ErrorUtils} from "./../../utils/ErrorUtils.sol";
import {Subaccount} from "../util/Subaccount.sol";
import {GmxPositionUtils} from "../util/GmxPositionUtils.sol";
import {SubaccountLogic} from "./../util/SubaccountLogic.sol";
import {PuppetUtils} from "./../util/PuppetUtils.sol";

import {PuppetLogic} from "./../PuppetLogic.sol";
import {PuppetStore} from "./../store/PuppetStore.sol";
import {PositionStore} from "../store/PositionStore.sol";
import {SubaccountStore} from "./../store/SubaccountStore.sol";

import {GmxOrder} from "./GmxOrder.sol";

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
        SubaccountStore subaccountStore;
        SubaccountLogic subaccountLogic;
        PositionStore positionStore;
        PuppetLogic puppetLogic;
        PuppetStore puppetStore;
        address dao;
        address gmxRouter;
        address gmxOrderVault;
        address feeReceiver;
        bytes32 referralCode;
        uint callbackGasLimit;
        uint limitPuppetList;
        uint minMatchTokenAmount;
    }

    struct CallParams {
        PuppetStore.Rule[] ruleList;
        PuppetStore.Activity[] activityList;
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

    function increase(RequestIncreasePosition.CallConfig calldata callConfig, GmxOrder.CallParams calldata traderCallParams, address from) internal {
        bytes32 positionKey =
            GmxPositionUtils.getPositionKey(from, traderCallParams.market, traderCallParams.collateralToken, traderCallParams.isLong);

        PositionStore.MirrorPosition memory mirrorPosition = callConfig.positionStore.getMirrorPosition(positionKey);

        bytes32 routeKey = PuppetUtils.getRouteKey(from, traderCallParams.collateralToken);
        (PuppetStore.Rule[] memory ruleList, PuppetStore.Activity[] memory activityList) =
            callConfig.puppetStore.getRuleAndActivityList(routeKey, traderCallParams.puppetList);

        Subaccount subaccount = callConfig.subaccountStore.getSubaccount(from);

        if (address(subaccount) == address(0)) {
            subaccount = callConfig.subaccountLogic.createSubaccount(callConfig.subaccountStore, from);
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

        if (mirrorPosition.size == 0) {
            PositionStore.RequestIncrease memory request = PositionStore.RequestIncrease({
                trader: from,
                puppetCollateralDeltaList: new uint[](traderCallParams.puppetList.length),
                leverage: traderCallParams.sizeDelta * Calc.BASIS_POINT_DIVISOR / traderCallParams.collateralDelta,
                leverageTarget: 0,
                collateralDelta: traderCallParams.collateralDelta,
                sizeDelta: traderCallParams.sizeDelta
            });

            open(callConfig, traderCallParams, callParams, request);
        } else {
            PositionStore.RequestIncrease memory requestParams = getAdjustRequestParams(traderCallParams, mirrorPosition, from);

            adjust(callConfig, traderCallParams, mirrorPosition, callParams, requestParams);
        }
    }

    function open(
        CallConfig calldata callConfig,
        GmxOrder.CallParams calldata traderCallParams,
        CallParams memory callParams,
        PositionStore.RequestIncrease memory request
    ) internal returns (bytes32 requestKey) {
        if (traderCallParams.puppetList.length > callConfig.limitPuppetList) revert RequestIncreasePosition__PuppetListLimitExceeded();

        for (uint i = 0; i < traderCallParams.puppetList.length; i++) {
            PuppetStore.Rule memory rule = callParams.ruleList[i];
            PuppetStore.Activity memory activity = callParams.activityList[i];

            if (
                rule.expiry < block.timestamp // rule expired or about to expire
                    || activity.latestFunding + rule.throttleActivity < block.timestamp // throttle in case of frequent matching
                    || activity.allowance <= rule.allowance // loss mitigation
            ) {
                continue;
            }

            uint minAmount = Math.min( // the lowest of either the allowance or the trader's deposit
                rule.allowance * rule.allowanceRate / Calc.BASIS_POINT_DIVISOR, // amount allowed by the rule
                traderCallParams.collateralDelta // trader own deposit
            );

            uint amountIn =
                sendTokenOptim(callConfig.router, callParams.collateralToken, traderCallParams.puppetList[i], callParams.subaccountAddress, minAmount);

            if (amountIn < callConfig.minMatchTokenAmount) {
                continue;
            }

            request.puppetCollateralDeltaList[i] = amountIn;

            activity.latestFunding = block.timestamp;
            activity.allowance -= amountIn; // reduce allowance by the amount matched

            callParams.totalCollateralDelta += amountIn;
            callParams.totalSizeDelta += amountIn * request.leverage / Calc.BASIS_POINT_DIVISOR;
            callParams.activityList[i] = activity;
        }

        callConfig.puppetLogic.setRouteActivityList(callConfig.puppetStore, callParams.routeKey, traderCallParams.puppetList, callParams.activityList);
        callConfig.positionStore.setRequestIncreaseMap(callParams.positionKey, request);

        requestKey = _createOrder(callConfig, traderCallParams, callParams, request);

        emit RequestIncreasePosition__Match(request.trader, callParams.subaccountAddress, requestKey, traderCallParams.puppetList);
    }

    function adjust(
        CallConfig calldata callConfig,
        GmxOrder.CallParams calldata traderCallParams,
        PositionStore.MirrorPosition memory mirrorPosition,
        CallParams memory callParams,
        PositionStore.RequestIncrease memory request
    ) internal returns (bytes32 requestKey) {
        if (traderCallParams.puppetList.length > callConfig.limitPuppetList) revert RequestIncreasePosition__PuppetListLimitExceeded();

        for (uint i = 0; i < mirrorPosition.puppetList.length; i++) {
            PuppetStore.Rule memory rule = callParams.ruleList[i];
            PuppetStore.Activity memory activity = callParams.activityList[i];

            uint depositAmount = mirrorPosition.puppetDepositList[i];

            // puppet's rule and activtiy applied per trader
            uint amountInTarget = rule.expiry < block.timestamp // filter out frequent deposit activity. defined during rule setup
                || activity.latestFunding + rule.throttleActivity < block.timestamp // expired rule. acounted every increase deposit
                || activity.allowance <= rule.allowance // stop loss. accounted every reduce adjustment
                || depositAmount == 0 // did not match initial deposit
                ? 0
                : sendTokenOptim(
                    callConfig.router,
                    callParams.collateralToken,
                    mirrorPosition.puppetList[i],
                    callParams.subaccountAddress,
                    traderCallParams.sizeDelta / depositAmount
                );

            if (amountInTarget > 0) {
                request.puppetCollateralDeltaList[i] += amountInTarget;
                callParams.totalSizeDelta += mirrorPosition.puppetDepositList[i] * traderCallParams.sizeDelta / mirrorPosition.size;
                callParams.totalCollateralDelta += amountInTarget;

                activity.latestFunding = block.timestamp;
                callParams.activityList[i] = activity;
            } else {
                if (request.leverageTarget > request.leverage) {
                    callParams.totalSizeDelta +=
                        depositAmount * request.leverage * Calc.diff(request.leverageTarget, request.leverage) / request.leverage;
                } else {
                    callParams.reducePuppetSizeDelta +=
                        depositAmount * request.leverage * Calc.diff(request.leverageTarget, request.leverage) / request.leverage;
                }
            }
        }

        callConfig.puppetLogic.setRouteActivityList(callConfig.puppetStore, callParams.routeKey, traderCallParams.puppetList, callParams.activityList);
        callConfig.positionStore.setRequestIncreaseMap(callParams.positionKey, request);

        if (callParams.totalSizeDelta > callParams.reducePuppetSizeDelta) {
            requestKey = _createOrder(callConfig, traderCallParams, callParams, request);
        } else {
            callParams.totalSizeDelta = 0;
            callParams.reducePuppetSizeDelta = callParams.reducePuppetSizeDelta;
            // callConfig.positionStore.setRequestReduceTargetLeverageMap(callParams.positionKey, request);
            bytes32 key = _reducePuppetSizeDelta(callConfig, traderCallParams, callParams);
            requestKey = _createOrder(callConfig, traderCallParams, callParams, request);

            emit RequestIncreasePosition__RequestReducePuppetSize(
                request.trader, callParams.subaccountAddress, requestKey, key, callParams.reducePuppetSizeDelta
            );
        }
    }

    function _createOrder(
        CallConfig calldata callConfig, //
        GmxOrder.CallParams calldata traderCallParams,
        CallParams memory callParams,
        PositionStore.RequestIncrease memory request
    ) internal returns (bytes32 requestKey) {
        GmxPositionUtils.CreateOrderParams memory orderParams = GmxPositionUtils.CreateOrderParams({
            addresses: GmxPositionUtils.CreateOrderParamsAddresses({
                receiver: callParams.positionStoreAddress,
                callbackContract: msg.sender,
                uiFeeReceiver: callConfig.feeReceiver,
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

        callParams.subaccount.approveToken(callConfig.gmxRouter, callParams.collateralToken, traderCallParams.collateralDelta);
        callConfig.router.pluginTransfer(callParams.collateralToken, request.trader, callParams.subaccountAddress, traderCallParams.collateralDelta);

        bool orderSuccess;
        bytes memory orderReturnData;

        if (traderCallParams.collateralToken == address(callConfig.wnt)) {
            uint totalValue = traderCallParams.executionFee + traderCallParams.collateralDelta;

            bytes[] memory callList = new bytes[](2);
            callList[0] = abi.encodeWithSelector(callConfig.gmxExchangeRouter.sendWnt.selector, callConfig.gmxOrderVault, totalValue);
            callList[1] = abi.encodeWithSelector(callConfig.gmxExchangeRouter.createOrder.selector, orderParams);

            (orderSuccess, orderReturnData) = callParams.subaccount.execute{value: msg.value}(
                address(callConfig.gmxExchangeRouter), abi.encodeWithSelector(callConfig.gmxExchangeRouter.multicall.selector, callList)
            );
        } else {
            bytes[] memory callList = new bytes[](3);
            callList[0] =
                abi.encodeWithSelector(callConfig.gmxExchangeRouter.sendWnt.selector, callConfig.gmxOrderVault, traderCallParams.executionFee);
            callList[1] = abi.encodeWithSelector(
                callConfig.gmxExchangeRouter.sendTokens.selector,
                traderCallParams.collateralToken,
                callConfig.gmxOrderVault,
                traderCallParams.collateralDelta
            );
            callList[2] = abi.encodeWithSelector(callConfig.gmxExchangeRouter.createOrder.selector, orderParams);

            (orderSuccess, orderReturnData) = callParams.subaccount.execute{value: msg.value}(
                address(callConfig.gmxExchangeRouter), abi.encodeWithSelector(callConfig.gmxExchangeRouter.multicall.selector, callList)
            );
        }

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
        CallConfig calldata gmxCallConfig, //
        GmxOrder.CallParams calldata traderCallparams,
        CallParams memory callParams
    ) internal returns (bytes32 requestKey) {
        GmxPositionUtils.CreateOrderParams memory params = GmxPositionUtils.CreateOrderParams({
            addresses: GmxPositionUtils.CreateOrderParamsAddresses({
                receiver: callParams.positionStoreAddress,
                callbackContract: msg.sender,
                uiFeeReceiver: gmxCallConfig.feeReceiver,
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
                callbackGasLimit: gmxCallConfig.callbackGasLimit,
                minOutputAmount: 0
            }),
            orderType: GmxPositionUtils.OrderType.MarketDecrease,
            decreasePositionSwapType: GmxPositionUtils.DecreasePositionSwapType.NoSwap,
            isLong: traderCallparams.isLong,
            shouldUnwrapNativeToken: false,
            referralCode: gmxCallConfig.referralCode
        });

        (bool orderSuccess, bytes memory orderReturnData) = callParams.subaccount.execute(
            address(gmxCallConfig.gmxExchangeRouter), abi.encodeWithSelector(gmxCallConfig.gmxExchangeRouter.createOrder.selector, params)
        );
        if (!orderSuccess) ErrorUtils.revertWithParsedMessage(orderReturnData);

        requestKey = abi.decode(orderReturnData, (bytes32));
    }

    // optimistically send token, 0 allocated if failed
    function sendTokenOptim(Router router, IERC20 token, address from, address to, uint amount) internal returns (uint) {
        (bool success, bytes memory returndata) = address(token).call(abi.encodeCall(router.pluginTransfer, (token, from, to, amount)));

        if (success && returndata.length == 0 && abi.decode(returndata, (bool))) return amount;

        return 0;
    }

    function getAdjustRequestParams(GmxOrder.CallParams calldata traderCallParams, PositionStore.MirrorPosition memory mirrorPosition, address from)
        internal
        pure
        returns (PositionStore.RequestIncrease memory)
    {
        uint leverage = mirrorPosition.size * Calc.BASIS_POINT_DIVISOR / mirrorPosition.collateral;
        uint leverageTarget = (mirrorPosition.size + traderCallParams.sizeDelta) * Calc.BASIS_POINT_DIVISOR
            / (mirrorPosition.collateral + traderCallParams.collateralDelta);

        return PositionStore.RequestIncrease({
            trader: from,
            puppetCollateralDeltaList: new uint[](traderCallParams.puppetList.length),
            leverage: leverage,
            leverageTarget: leverageTarget,
            collateralDelta: traderCallParams.collateralDelta,
            sizeDelta: traderCallParams.sizeDelta
        });
    }

    error RequestIncreasePosition__PuppetListLimitExceeded();
}
