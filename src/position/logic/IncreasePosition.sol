// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IGmxExchangeRouter} from "../interface/IGmxExchangeRouter.sol";
import {IGmxDatastore} from "../interface/IGmxDatastore.sol";

import {Router} from "src/utils/Router.sol";
import {Calc} from "src/utils/Calc.sol";

import {ErrorUtils} from "./../../utils/ErrorUtils.sol";
import {PositionUtils} from "../util/PositionUtils.sol";
import {Subaccount} from "../util/Subaccount.sol";

import {PuppetStore} from "../store/PuppetStore.sol";
import {PositionStore} from "../store/PositionStore.sol";
import {SubaccountStore} from "./../store/SubaccountStore.sol";

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
library IncreasePosition {
    event IncreasePosition__RequestMatchPosition(address trader, address subAccount, bytes32 requestKey, address[] puppetList);
    event IncreasePosition__RequestIncreasePosition(
        address trader, address subAccount, bytes32 requestKey, uint[] puppetCollateralDeltaList, uint collateralDelta, uint sizeDelta
    );

    struct CallConfig {
        Router router;
        SubaccountStore subaccountStore;
        PositionStore positionStore;
        PuppetStore puppetStore;
        IGmxExchangeRouter gmxExchangeRouter;
        IGmxDatastore gmxDatastore;
        IERC20 depositCollateralToken;
        address gmxCallbackOperator;
        address feeReceiver;
        address trader;
        bytes32 referralCode;
        uint limitPuppetList;
        uint adjustmentFeeFactor;
        uint callbackGasLimit;
        uint minMatchTokenAmount;
    }

    struct CallParams {
        address market;
        uint executionFee;
        uint sizeDelta;
        uint collateralDelta;
        uint acceptablePrice;
        uint triggerPrice;
        bool isLong;
        address[] puppetList;
    }

    struct CallbackConfig {
        PositionStore positionStore;
        PuppetStore puppetStore;
        address gmxCallbackOperator;
        address caller;
    }

    function requestIncreasePosition(CallConfig calldata callConfig, CallParams calldata callParams) external {
        bytes32 positionKey = PositionUtils.getPositionKey(callConfig.trader, callParams.market, callConfig.depositCollateralToken, callParams.isLong);

        if (callConfig.positionStore.getPendingRequestIncreaseAdjustmentMap(positionKey).requestKey != 0) {
            revert IncreasePosition__PendingRequestExists();
        }

        Subaccount subaccount = callConfig.subaccountStore.getSubaccount(callConfig.trader);
        PositionStore.MirrorPosition memory matchMp = callConfig.positionStore.getMirrorPosition(positionKey);
        PositionStore.RequestIncrease memory request = PositionStore.RequestIncrease({
            requestKey: PositionUtils.getNextRequestKey(callConfig.gmxDatastore),
            sizeDelta: int(callParams.sizeDelta),
            collateralDelta: callParams.collateralDelta,
            targetLeverage: 0,
            puppetCollateralDeltaList: new uint[](callParams.puppetList.length),
            positionKey: positionKey,
            subaccount: subaccount,
            subaccountAddress: address(subaccount)
        });

        if (matchMp.size == 0) {
            requestMatch(callConfig, callParams, request);
        } else {
            requestAdjust(callConfig, callParams, request);
        }
    }

    function requestMatch(CallConfig calldata callConfig, CallParams calldata callParams, PositionStore.RequestIncrease memory request) internal {
        uint puppetListLength = callParams.puppetList.length;
        if (puppetListLength > callConfig.limitPuppetList) revert IncreasePosition__PuppetListLimitExceeded();

        (PuppetStore.Rule[] memory ruleList, PuppetStore.Activity[] memory activityList) =
            callConfig.puppetStore.getTraderRuleAndActivityList(callConfig.trader, callParams.puppetList);

        request.targetLeverage = callParams.sizeDelta * Calc.BASIS_POINT_DIVISOR / callParams.collateralDelta;

        for (uint i = 0; i < puppetListLength; i++) {
            PuppetStore.Rule memory rule = ruleList[i];
            PuppetStore.Activity memory activity = activityList[i];

            uint amountIn = rule.expiry < block.timestamp // rule expired or about to expire
                || activity.latestFunding + rule.throttleActivity < block.timestamp // throttle in case of frequent matching
                || activity.pnl < -int(rule.stopLoss) // stop loss. accounted every reduce adjustment
                ? 0
                : transferTokenFrom(
                    callConfig.depositCollateralToken,
                    callParams.puppetList[i],
                    request.subaccountAddress,
                    Math.min( // the lowest of either the allowance or the trader's deposit
                        rule.stopLoss * rule.allowanceRate / Calc.BASIS_POINT_DIVISOR, // amount allowed by the rule
                        callParams.collateralDelta // trader own deposit
                    )
                );

            if (amountIn < callConfig.minMatchTokenAmount) {
                continue;
            }

            request.puppetCollateralDeltaList[i] = amountIn;
            request.sizeDelta += int(amountIn * request.targetLeverage / Calc.BASIS_POINT_DIVISOR);
            request.collateralDelta += amountIn;

            activity.latestFunding = block.timestamp;
            activityList[i] = activity;
        }

        emit IncreasePosition__RequestMatchPosition(callConfig.trader, request.subaccountAddress, request.requestKey, callParams.puppetList);

        _requestIncreasePosition(callConfig, callParams, request);

        callConfig.positionStore.setPendingRequestIncreaseAdjustmentMap(request.positionKey, request);
    }

    function requestAdjust(CallConfig calldata callConfig, CallParams calldata callParams, PositionStore.RequestIncrease memory request) internal {
        PositionStore.MirrorPosition memory matchMp = callConfig.positionStore.getMirrorPosition(request.positionKey);
        uint puppetListLength = matchMp.puppetList.length;

        request.targetLeverage = (matchMp.size + callParams.sizeDelta) * Calc.BASIS_POINT_DIVISOR / (matchMp.collateral + callParams.collateralDelta);

        (PuppetStore.Rule[] memory ruleList, PuppetStore.Activity[] memory activityList) =
            callConfig.puppetStore.getTraderRuleAndActivityList(callConfig.trader, matchMp.puppetList);

        for (uint i = 0; i < puppetListLength; i++) {
            PuppetStore.Rule memory rule = ruleList[i];
            PuppetStore.Activity memory activity = activityList[i];

            address puppet = matchMp.puppetList[i];

            // puppet's rule and activtiy applied per trader
            uint amountInTarget = rule.expiry < block.timestamp // filter out frequent deposit activity. defined during rule setup
                || activity.latestFunding + rule.throttleActivity < block.timestamp // expired rule. acounted every increase deposit
                || activity.pnl < -int(rule.stopLoss) // stop loss. accounted every reduce adjustment
                || matchMp.puppetDepositList[i] == 0 // no activity
                ? 0
                : transferTokenFrom(
                    callConfig.depositCollateralToken, puppet, request.subaccountAddress, callParams.sizeDelta / matchMp.puppetDepositList[i]
                );

            if (amountInTarget > 0) {
                request.puppetCollateralDeltaList[i] += amountInTarget;
                request.collateralDelta += amountInTarget;

                activity.latestFunding = block.timestamp;
                activityList[i] = activity;
                request.sizeDelta += int(matchMp.puppetDepositList[i] * callParams.sizeDelta / matchMp.size);
            } else {
                if (matchMp.leverage > request.targetLeverage) {
                    request.sizeDelta += int(amountInTarget * request.targetLeverage * (matchMp.leverage - request.targetLeverage) / matchMp.leverage);
                } else {
                    request.sizeDelta -= int(amountInTarget * request.targetLeverage * (matchMp.leverage - request.targetLeverage) / matchMp.leverage);
                }
            }
        }

        callConfig.puppetStore.setTraderActivityList(callConfig.trader, matchMp.puppetList, activityList);

        _requestIncreasePosition(callConfig, callParams, request);

        // size delta is negative and deposit positive, additional transaction is required to match the leverage
        if (request.sizeDelta < 0) {
            callConfig.positionStore.setPendingRequestIncreaseAdjustmentMap(request.positionKey, request);
        }
    }

    function executeIncreasePosition(CallbackConfig calldata callConfig, bytes32 key, PositionUtils.Props calldata order, bytes calldata eventData)
        external
    {
        callConfig.positionStore.removePendingRequestIncreaseAdjustmentMap(key);
    }

    function _requestIncreasePosition(
        CallConfig calldata callConfig,
        CallParams calldata callPositionAdjustment,
        PositionStore.RequestIncrease memory request
    ) internal returns (bytes32 requestKey) {
        address subaccountAddress = request.subaccount.account();

        if (subaccountAddress != callConfig.trader) revert IncreasePosition__InvalidSubaccountTrader();

        request.subaccount.depositToken(callConfig.router, callConfig.depositCollateralToken, callPositionAdjustment.collateralDelta);
        SafeERC20.safeTransferFrom(callConfig.depositCollateralToken, address(callConfig.puppetStore), subaccountAddress, request.collateralDelta);

        PositionUtils.CreateOrderParams memory params = PositionUtils.CreateOrderParams(
            PositionUtils.CreateOrderParamsAddresses(
                address(callConfig.subaccountStore),
                callConfig.gmxCallbackOperator,
                callConfig.feeReceiver,
                callPositionAdjustment.market,
                address(callConfig.depositCollateralToken),
                new address[](0) // swapPath
            ),
            PositionUtils.CreateOrderParamsNumbers(
                request.sizeDelta > 0 ? uint(request.sizeDelta) : 0,
                request.collateralDelta,
                callPositionAdjustment.triggerPrice,
                callPositionAdjustment.acceptablePrice,
                callPositionAdjustment.executionFee,
                callConfig.callbackGasLimit,
                0 // _minOut - 0 since we are not swapping
            ),
            PositionUtils.OrderType.MarketIncrease,
            PositionUtils.DecreasePositionSwapType.NoSwap,
            callPositionAdjustment.isLong,
            false, // shouldUnwrapNativeToken
            callConfig.referralCode
        );

        bytes memory data = abi.encodeWithSelector(callConfig.gmxExchangeRouter.createOrder.selector, params);
        (bool success, bytes memory returnData) = request.subaccount.execute(address(callConfig.gmxExchangeRouter), data);
        if (!success) ErrorUtils.revertWithParsedMessage(returnData);

        requestKey = abi.decode(returnData, (bytes32));

        emit IncreasePosition__RequestIncreasePosition(
            callConfig.trader, subaccountAddress, requestKey, request.puppetCollateralDeltaList, request.collateralDelta, uint(request.sizeDelta)
        );
    }

    function transferTokenFrom(IERC20 token, address from, address to, uint amount) internal returns (uint) {
        (bool success, bytes memory returndata) = address(token).call(abi.encodeCall(token.transferFrom, (from, to, amount)));

        if (success && returndata.length == 0 && abi.decode(returndata, (bool))) {
            return amount;
        }

        return 0;
    }

    error IncreasePosition__PuppetListLimitExceeded();
    error IncreasePosition__InvalidRequestKey(bytes32 requestKey, bytes32 expectedRequestKey);
    error IncreasePosition__InvalidSubaccountTrader();
    error IncreasePosition__PendingRequestExists();
}
