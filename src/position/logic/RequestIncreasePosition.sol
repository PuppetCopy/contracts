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
import {TransferUtils} from "./../../utils/TransferUtils.sol";

import {PuppetLogic} from "./../PuppetLogic.sol";
import {PuppetStore} from "./../store/PuppetStore.sol";
import {PositionStore} from "../store/PositionStore.sol";
import {SubaccountStore} from "./../store/SubaccountStore.sol";

import {GmxOrder} from "./GmxOrder.sol";

/*
    increase adjustment case study
    increase require more complex accounting compared to decrease, matching the same leverage which may require additional funds

    Puppet Size Delta: (Position Size * (Leverage - Target Leverage) / Leverage)

    Columns: User, Size Delta / Collateral Delta, Position Size / Position Collateral

    1. Open 1000/100 10x

    Trader                +1000   / +100       1000   / 100
    -------------------------------------------------------
    Puppet A              +100    / +10        100    / 10
    Puppet B              +1000   / +100       1000   / 100
    MP 10x                +2100   / +210       2100   / 210

    in the following cases Puppet B cannot add any funds (due to insolvency, throttle or expiry), to match MP leverage only size will be adjusted
    to, if size is greater than deposit, size can be adjust to match the leverage without adding funds

    2.A Increase 100%/50%  20x, 3.33x delta
    adjust size but no collateral change

    Trader                +1000   / +50        2000   / 150
    -------------------------------------------------------
    Puppet A              +100    / +5         200    / 15
    Puppet B (Reduce)     +333.3  / 0          1333.3 / 100
    MP 13.33x             +1433.3 / +55        3533.3 / 265

    2.B Increase 50%/100% -2.5x delta
    shift size from Puppet B to others

    Trader                +500    / +100       1500   / 200
    -------------------------------------------------------
    Puppet A              +50     / +10        150    / 20
    Puppet B (Reduce)     -250    / 0          750    / 100
    MP 7.5x               +300    / +110       2400   / 320

    2.C Increase 10% / 100% 4.5x -4.5x delta
    if net size is less than deposit, MP size has to be reduced in additional transaction(*)
    requiring an additional transaction is not optimal beucase it forces adjustments to remain sequential, but it is necessary to match the leverage
    (is there a better solution?)

    Trader                +110    / +100       1100   / 200
    -------------------------------------------------------
    Puppet A              +10     / +10        110    / 20
    Puppet B (Reduce)     -450*   / 0          550   / 100
    MP 5.5x               -450*   / +110       1760  / 320

    */

library RequestIncreasePosition {
    event RequestIncreasePosition__Match(address trader, address subaccount, bytes32 requestKey, address[] puppetList);
    event RequestIncreasePosition__Request(
        address trader,
        address subaccount,
        bytes32 requestKey,
        uint[] puppetCollateralDeltaList,
        uint sizeDelta,
        uint reducePuppetSizeDelta,
        uint collateralDelta
    );
    event RequestIncreasePosition__RequestReduceTargetLeverage(
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

    function open(
        CallConfig calldata callConfig,
        GmxOrder.CallParams calldata callParams,
        PositionStore.RequestAdjustment memory request,
        address subaccountAddress
    ) external returns (bytes32 requestKey) {
        (PuppetStore.Rule[] memory ruleList, PuppetStore.Activity[] memory activityList) =
            callConfig.puppetStore.getRuleAndActivityList(request.routeKey, callParams.puppetList);

        if (callParams.puppetList.length > callConfig.limitPuppetList) revert RequestIncreasePosition__PuppetListLimitExceeded();

        request.targetLeverage = callParams.sizeDelta * Calc.BASIS_POINT_DIVISOR / callParams.collateralDelta;

        for (uint i = 0; i < callParams.puppetList.length; i++) {
            PuppetStore.Rule memory rule = ruleList[i];
            PuppetStore.Activity memory activity = activityList[i];

            if (
                rule.expiry < block.timestamp // rule expired or about to expire
                    || activity.latestFunding + rule.throttleActivity < block.timestamp // throttle in case of frequent matching
                    || activity.allowance <= rule.allowance // loss mitigation
            ) {
                continue;
            }

            uint minAmount = Math.min( // the lowest of either the allowance or the trader's deposit
                rule.allowance * rule.allowanceRate / Calc.BASIS_POINT_DIVISOR, // amount allowed by the rule
                callParams.collateralDelta // trader own deposit
            );

            uint amountIn = sendTokenOptim(callConfig.router, request.collateralToken, callParams.puppetList[i], subaccountAddress, minAmount);

            if (amountIn < callConfig.minMatchTokenAmount) {
                continue;
            }

            request.puppetCollateralDeltaList[i] = amountIn;
            request.collateralDelta += amountIn;
            request.sizeDelta += amountIn * request.targetLeverage / Calc.BASIS_POINT_DIVISOR;

            activity.latestFunding = block.timestamp;
            activity.allowance -= amountIn; // reduce allowance by the amount matched
            activityList[i] = activity;
        }

        callConfig.puppetLogic.setRouteActivityList(callConfig.puppetStore, request.routeKey, callParams.puppetList, activityList);
        callConfig.positionStore.setPendingRequestMap(request.positionKey, request);

        requestKey = _createOrder(callConfig, callParams, request);

        emit RequestIncreasePosition__Match(request.trader, subaccountAddress, requestKey, callParams.puppetList);
        emit RequestIncreasePosition__Request(
            request.trader,
            subaccountAddress,
            requestKey,
            request.puppetCollateralDeltaList,
            request.sizeDelta,
            request.reducePuppetSizeDelta,
            request.collateralDelta
        );
    }

    function adjust(
        CallConfig calldata callConfig,
        GmxOrder.CallParams calldata callParams,
        PositionStore.MirrorPosition memory mirrorPosition,
        PositionStore.RequestAdjustment memory request
    ) external returns (bytes32 requestKey) {
        (PuppetStore.Rule[] memory ruleList, PuppetStore.Activity[] memory activityList) =
            callConfig.puppetStore.getRuleAndActivityList(request.routeKey, callParams.puppetList);

        if (callParams.puppetList.length > callConfig.limitPuppetList) revert RequestIncreasePosition__PuppetListLimitExceeded();

        request.targetLeverage =
            (mirrorPosition.size + callParams.sizeDelta) * Calc.BASIS_POINT_DIVISOR / (mirrorPosition.collateral + callParams.collateralDelta);

        for (uint i = 0; i < mirrorPosition.puppetList.length; i++) {
            PuppetStore.Rule memory rule = ruleList[i];
            PuppetStore.Activity memory activity = activityList[i];

            // puppet's rule and activtiy applied per trader
            uint amountInTarget = rule.expiry < block.timestamp // filter out frequent deposit activity. defined during rule setup
                || activity.latestFunding + rule.throttleActivity < block.timestamp // expired rule. acounted every increase deposit
                || activity.allowance <= rule.allowance // stop loss. accounted every reduce adjustment
                || mirrorPosition.puppetDepositList[i] == 0 // did not match initial deposit
                ? 0
                : sendTokenOptim(
                    callConfig.router,
                    request.collateralToken,
                    mirrorPosition.puppetList[i],
                    address(request.subaccount),
                    callParams.sizeDelta / mirrorPosition.puppetDepositList[i]
                );

            if (amountInTarget > 0) {
                request.puppetCollateralDeltaList[i] += amountInTarget;
                request.collateralDelta += amountInTarget;
                request.sizeDelta += mirrorPosition.puppetDepositList[i] * callParams.sizeDelta / mirrorPosition.size;

                activity.latestFunding = block.timestamp;
                activityList[i] = activity;
            } else {
                uint leverage = mirrorPosition.collateral * Calc.BASIS_POINT_DIVISOR / mirrorPosition.size;
                if (leverage > request.targetLeverage) {
                    request.sizeDelta += amountInTarget * request.targetLeverage * (leverage - request.targetLeverage) / leverage;
                } else {
                    request.reducePuppetSizeDelta += amountInTarget * request.targetLeverage * (leverage - request.targetLeverage) / leverage;
                }
            }
        }

        if (request.reducePuppetSizeDelta > request.sizeDelta) {
            request.sizeDelta = 0;
            request.reducePuppetSizeDelta = request.reducePuppetSizeDelta - request.sizeDelta;
        }

        callConfig.puppetLogic.setRouteActivityList(callConfig.puppetStore, request.routeKey, callParams.puppetList, activityList);
        callConfig.positionStore.setPendingRequestMap(request.positionKey, request);

        requestKey = _createOrder(callConfig, callParams, request);

        if (request.reducePuppetSizeDelta > 0) {
            callConfig.positionStore.setRequestReduceTargetLeverageMap(request.positionKey, request);
            bytes32 reduceRequestKey = _adjustToTargetLeverage(callConfig, callParams, request);
            emit RequestIncreasePosition__RequestReduceTargetLeverage(
                request.trader, address(request.subaccount), requestKey, reduceRequestKey, request.reducePuppetSizeDelta
            );
        }

        emit RequestIncreasePosition__Request(
            request.trader,
            address(request.subaccount),
            requestKey,
            request.puppetCollateralDeltaList,
            request.sizeDelta,
            request.reducePuppetSizeDelta,
            request.collateralDelta
        );
    }

    function _createOrder(CallConfig calldata callConfig, GmxOrder.CallParams calldata callParams, PositionStore.RequestAdjustment memory request)
        internal
        returns (bytes32 requestKey)
    {
        GmxPositionUtils.CreateOrderParams memory orderParams = GmxPositionUtils.CreateOrderParams({
            addresses: GmxPositionUtils.CreateOrderParamsAddresses({
                receiver: address(callConfig.positionStore),
                callbackContract: msg.sender,
                uiFeeReceiver: callConfig.feeReceiver,
                market: callParams.market,
                initialCollateralToken: callParams.collateralToken,
                swapPath: new address[](0) // swapPath
            }),
            numbers: GmxPositionUtils.CreateOrderParamsNumbers({
                initialCollateralDeltaAmount: request.collateralDelta,
                sizeDeltaUsd: request.reducePuppetSizeDelta,
                triggerPrice: callParams.triggerPrice,
                acceptablePrice: callParams.acceptablePrice,
                executionFee: callParams.executionFee,
                callbackGasLimit: callConfig.callbackGasLimit,
                minOutputAmount: 0
            }),
            orderType: GmxPositionUtils.OrderType.MarketIncrease,
            decreasePositionSwapType: GmxPositionUtils.DecreasePositionSwapType.NoSwap,
            isLong: callParams.isLong,
            shouldUnwrapNativeToken: false,
            referralCode: callConfig.referralCode
        });

        request.subaccount.approveToken(callConfig.gmxRouter, request.collateralToken, callParams.collateralDelta);
        callConfig.router.pluginTransfer(request.collateralToken, request.trader, address(request.subaccount), callParams.collateralDelta);

        bool orderSuccess;
        bytes memory orderReturnData;

        if (callParams.collateralToken == address(0)) {
            uint totalValue = callParams.executionFee + callParams.collateralDelta;

            bytes[] memory callList = new bytes[](2);
            callList[0] = abi.encodeWithSelector(callConfig.gmxExchangeRouter.sendWnt.selector, callConfig.gmxOrderVault, totalValue);
            callList[1] = abi.encodeWithSelector(callConfig.gmxExchangeRouter.createOrder.selector, orderParams);

            (orderSuccess, orderReturnData) = request.subaccount.execute{value: msg.value}(
                address(callConfig.gmxExchangeRouter), abi.encodeWithSelector(callConfig.gmxExchangeRouter.multicall.selector, callList)
            );
        } else {
            bytes[] memory callList = new bytes[](3);
            callList[0] = abi.encodeWithSelector(callConfig.gmxExchangeRouter.sendWnt.selector, callConfig.gmxOrderVault, callParams.executionFee);
            callList[1] = abi.encodeWithSelector(
                callConfig.gmxExchangeRouter.sendTokens.selector, callParams.collateralToken, callConfig.gmxOrderVault, callParams.collateralDelta
            );
            callList[2] = abi.encodeWithSelector(callConfig.gmxExchangeRouter.createOrder.selector, orderParams);

            (orderSuccess, orderReturnData) = request.subaccount.execute{value: msg.value}(
                address(callConfig.gmxExchangeRouter), abi.encodeWithSelector(callConfig.gmxExchangeRouter.multicall.selector, callList)
            );
        }

        if (!orderSuccess) ErrorUtils.revertWithParsedMessage(orderReturnData);

        requestKey = abi.decode(orderReturnData, (bytes32));
    }

    function _adjustToTargetLeverage(
        CallConfig calldata gmxCallConfig,
        GmxOrder.CallParams calldata callParams,
        PositionStore.RequestAdjustment memory request
    ) internal returns (bytes32 requestKey) {
        GmxPositionUtils.CreateOrderParams memory params = GmxPositionUtils.CreateOrderParams({
            addresses: GmxPositionUtils.CreateOrderParamsAddresses({
                receiver: address(gmxCallConfig.positionStore),
                callbackContract: msg.sender,
                uiFeeReceiver: gmxCallConfig.feeReceiver,
                market: callParams.market,
                initialCollateralToken: callParams.collateralToken,
                swapPath: new address[](0) // swapPath
            }),
            numbers: GmxPositionUtils.CreateOrderParamsNumbers({
                initialCollateralDeltaAmount: 0,
                sizeDeltaUsd: request.sizeDelta,
                triggerPrice: callParams.triggerPrice,
                acceptablePrice: callParams.acceptablePrice,
                executionFee: callParams.executionFee,
                callbackGasLimit: gmxCallConfig.callbackGasLimit,
                minOutputAmount: 0
            }),
            orderType: GmxPositionUtils.OrderType.MarketDecrease,
            decreasePositionSwapType: GmxPositionUtils.DecreasePositionSwapType.NoSwap,
            isLong: callParams.isLong,
            shouldUnwrapNativeToken: false,
            referralCode: gmxCallConfig.referralCode
        });

        (bool orderSuccess, bytes memory orderReturnData) = Subaccount(request.subaccount).execute(
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

    error RequestIncreasePosition__PuppetListLimitExceeded();
}
