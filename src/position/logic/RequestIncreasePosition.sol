// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IGmxDatastore} from "../interface/IGmxDatastore.sol";
import {Router} from "./../../utils/Router.sol";

import {Calc} from "src/utils/Calc.sol";

import {GmxPositionUtils} from "../util/GmxPositionUtils.sol";
import {Subaccount} from "../util/Subaccount.sol";

import {PuppetUtils} from "./../util/PuppetUtils.sol";

import {PuppetLogic} from "./../PuppetLogic.sol";
import {PuppetStore} from "./../store/PuppetStore.sol";
import {PositionStore} from "../store/PositionStore.sol";
import {PositionLogic} from "./../PositionLogic.sol";

import {GmxOrder} from "./GmxOrder.sol";
import {ErrorUtils} from "./../../utils/ErrorUtils.sol";

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
    event RequestIncreasePosition__RequestMatchPosition(address trader, address subAccount, bytes32 requestKey, address[] puppetList);
    event RequestIncreasePosition__RequestIncreasePosition(
        address trader, address subAccount, bytes32 requestKey, uint[] puppetCollateralDeltaList, int sizeDelta, uint collateralDelta
    );

    struct RequestConfig {
        PositionLogic positionLogic;
        PuppetLogic puppetLogic;
        PuppetStore puppetStore;
        IGmxDatastore gmxDatastore;
        uint limitPuppetList;
        uint minMatchTokenAmount;
    }

    function call(
        GmxOrder.CallConfig calldata gmxCallConfig,
        RequestConfig calldata callConfig,
        GmxOrder.CallParams calldata callParams,
        Subaccount subaccount
    ) external returns (PositionStore.RequestIncrease memory request) {
        request = PositionStore.RequestIncrease({
            requestKey: GmxPositionUtils.getNextRequestKey(callConfig.gmxDatastore),
            routeKey: PuppetUtils.getRouteKey(subaccount.account(), callParams.collateralToken),
            sizeDelta: int(callParams.sizeDelta),
            collateralDelta: callParams.collateralDelta,
            targetLeverage: 0,
            puppetCollateralDeltaList: new uint[](callParams.puppetList.length),
            positionKey: GmxPositionUtils.getPositionKey(address(subaccount), callParams.market, callParams.collateralToken, callParams.isLong),
            collateralToken: IERC20(callParams.collateralToken),
            subaccount: address(subaccount),
            trader: subaccount.account(),
            mirrorPosition: gmxCallConfig.positionStore.getMirrorPosition(request.positionKey)
        });

        if (gmxCallConfig.positionStore.getPendingRequestIncreaseAdjustmentMap(request.positionKey).targetLeverage != 0) {
            revert RequestIncreasePosition__PendingIncreaseRequestExists();
        }

        (PuppetStore.Rule[] memory ruleList, PuppetStore.Activity[] memory activityList) =
            callConfig.puppetStore.getRuleAndActivityList(request.routeKey, callParams.puppetList);

        if (request.mirrorPosition.size == 0) {
            if (callParams.puppetList.length > callConfig.limitPuppetList) revert RequestIncreasePosition__PuppetListLimitExceeded();

            gmxCallConfig.positionStore.setPendingRequestIncreaseAdjustmentMap(request.positionKey, request);

            request.targetLeverage = callParams.sizeDelta * Calc.BASIS_POINT_DIVISOR / callParams.collateralDelta;

            for (uint i = 0; i < callParams.puppetList.length; i++) {
                PuppetStore.Rule memory rule = ruleList[i];
                PuppetStore.Activity memory activity = activityList[i];

                if (
                    rule.expiry < block.timestamp // rule expired or about to expire
                        || activity.latestFunding + rule.throttleActivity < block.timestamp // throttle in case of frequent matching
                        || activity.pnl < int(rule.allowance) // stop loss. accounted every reduce adjustment
                ) {
                    continue;
                }

                uint amountIn = _transferTokenFrom(
                    gmxCallConfig.router,
                    request.collateralToken,
                    callParams.puppetList[i],
                    request.subaccount,
                    Math.min( // the lowest of either the allowance or the trader's deposit
                        rule.allowance * rule.allowanceRate / Calc.BASIS_POINT_DIVISOR, // amount allowed by the rule
                        callParams.collateralDelta // trader own deposit
                    )
                );

                if (amountIn < callConfig.minMatchTokenAmount) {
                    continue;
                }

                request.puppetCollateralDeltaList[i] = amountIn;
                request.collateralDelta += amountIn;
                request.sizeDelta += int(amountIn * request.targetLeverage / Calc.BASIS_POINT_DIVISOR);

                activity.latestFunding = block.timestamp;
                activityList[i] = activity;
            }

            emit RequestIncreasePosition__RequestMatchPosition(request.trader, request.subaccount, request.requestKey, callParams.puppetList);
        } else {
            request.targetLeverage = (request.mirrorPosition.size + callParams.sizeDelta) * Calc.BASIS_POINT_DIVISOR
                / (request.mirrorPosition.collateral + callParams.collateralDelta);

            for (uint i = 0; i < request.mirrorPosition.puppetList.length; i++) {
                PuppetStore.Rule memory rule = ruleList[i];
                PuppetStore.Activity memory activity = activityList[i];

                // puppet's rule and activtiy applied per trader
                uint amountInTarget = rule.expiry < block.timestamp // filter out frequent deposit activity. defined during rule setup
                    || activity.latestFunding + rule.throttleActivity < block.timestamp // expired rule. acounted every increase deposit
                    // || activity.pnl < rule.stopLoss // stop loss. accounted every reduce adjustment
                    || request.mirrorPosition.puppetDepositList[i] == 0 // did not match initial deposit
                    ? 0
                    : _transferTokenFrom(
                        gmxCallConfig.router,
                        request.collateralToken,
                        request.mirrorPosition.puppetList[i],
                        request.subaccount,
                        callParams.sizeDelta / request.mirrorPosition.puppetDepositList[i]
                    );

                if (amountInTarget > 0) {
                    request.puppetCollateralDeltaList[i] += amountInTarget;
                    request.collateralDelta += amountInTarget;
                    request.sizeDelta += int(request.mirrorPosition.puppetDepositList[i] * callParams.sizeDelta / request.mirrorPosition.size);

                    activity.latestFunding = block.timestamp;
                    activityList[i] = activity;
                } else {
                    uint leverage = request.mirrorPosition.collateral * Calc.BASIS_POINT_DIVISOR / request.mirrorPosition.size;
                    if (leverage > request.targetLeverage) {
                        request.sizeDelta += int(amountInTarget * request.targetLeverage * (leverage - request.targetLeverage) / leverage);
                    } else {
                        request.sizeDelta -= int(amountInTarget * request.targetLeverage * (leverage - request.targetLeverage) / leverage);
                    }
                }
            }
        }

        callConfig.puppetLogic.setRouteActivityList(callConfig.puppetStore, request.routeKey, callParams.puppetList, activityList);

        bytes32 requestKey = _createOrder(gmxCallConfig, callParams, request, request.trader);

        emit RequestIncreasePosition__RequestIncreasePosition(
            request.trader, request.subaccount, requestKey, request.puppetCollateralDeltaList, request.sizeDelta, request.collateralDelta
        );
    }

    function _transferTokenFrom(Router router, IERC20 token, address from, address to, uint amount) internal returns (uint) {
        (bool success, bytes memory returndata) = address(token).call(abi.encodeCall(router.pluginTransfer, (token, from, to, amount)));

        if (success && returndata.length == 0 && abi.decode(returndata, (bool))) {
            return amount;
        }

        return 0;
    }

    function _createOrder(
        GmxOrder.CallConfig calldata callConfig,
        GmxOrder.CallParams calldata callParams,
        PositionStore.RequestIncrease memory request,
        address trader
    ) internal returns (bytes32 requestKey) {
        Subaccount subaccount = Subaccount(request.subaccount);

        GmxPositionUtils.CreateOrderParams memory params = GmxPositionUtils.CreateOrderParams({
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
                sizeDeltaUsd: request.sizeDelta > 0 ? uint(request.sizeDelta) : 0,
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

        callConfig.router.pluginTransfer(request.collateralToken, trader, address(request.subaccount), callParams.collateralDelta);
        subaccount.approveToken(callConfig.gmxRouter, request.collateralToken, callParams.collateralDelta);

        (bool orderSuccess, bytes memory orderReturnData) = subaccount.execute(
            address(callConfig.gmxExchangeRouter), abi.encodeWithSelector(callConfig.gmxExchangeRouter.createOrder.selector, params)
        );
        if (!orderSuccess) ErrorUtils.revertWithParsedMessage(orderReturnData); 

        requestKey = abi.decode(orderReturnData, (bytes32));

        if (request.sizeDelta < 0) {
            callConfig.positionStore.setPendingRequestIncreaseAdjustmentMap(request.positionKey, request);

            _adjustToTargetLeverage(callConfig, callParams, request);
        }
    }

    function _adjustToTargetLeverage(
        GmxOrder.CallConfig calldata gmxCallConfig,
        GmxOrder.CallParams calldata callParams,
        PositionStore.RequestIncrease memory request
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
                sizeDeltaUsd: uint(-request.sizeDelta),
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

    error RequestIncreasePosition__PuppetListLimitExceeded();
    error RequestIncreasePosition__PendingIncreaseRequestExists();
}
