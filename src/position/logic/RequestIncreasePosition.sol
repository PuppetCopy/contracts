// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IGmxExchangeRouter} from "./../interface/IGmxExchangeRouter.sol";

import {Router} from "./../../utils/Router.sol";
import {Precision} from "./../../utils/Precision.sol";
import {IWNT} from "./../../utils/interfaces/IWNT.sol";
import {ErrorUtils} from "./../../utils/ErrorUtils.sol";
import {GmxPositionUtils} from "../util/GmxPositionUtils.sol";

import {Subaccount} from "./../../shared/Subaccount.sol";
import {SubaccountFactory} from "./../../shared/SubaccountFactory.sol";
import {SubaccountStore} from "./../../shared/store/SubaccountStore.sol";

import {PuppetStore} from "./../store/PuppetStore.sol";

import {PuppetRouter} from "./../../PuppetRouter.sol";
import {PositionStore} from "../store/PositionStore.sol";

library RequestIncreasePosition {
    event RequestIncreasePosition__Match(address trader, address subaccount, bytes32 positionKey, bytes32 requestKey, address[] puppetList);
    event RequestIncreasePosition__Request(
        PositionStore.RequestIncrease request,
        address subaccount,
        bytes32 positionKey,
        bytes32 requestKey,
        uint traderSizeDelta,
        uint traderCollateralDelta
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
        PuppetRouter puppetRouter;
        PuppetStore puppetStore;
        address positionRouterAddress;
        address gmxRouter;
        address gmxOrderVault;
        bytes32 referralCode;
        uint callbackGasLimit;
        uint limitPuppetList;
        uint minimumMatchAmount;
        uint tokenTransferGasLimit;
    }

    struct TraderCallParams {
        address market;
        IERC20 collateralToken;
        bool isLong;
        uint executionFee;
        uint collateralDelta;
        uint sizeDelta;
        uint acceptablePrice;
        uint triggerPrice;
    }

    struct CallParams {
        bytes32 positionKey;
        PuppetStore.Rule[] ruleList;
        uint[] activityList;
        uint[] sampledAllowanceList;
        address subaccountAddress;
    }

    function increase(
        CallConfig memory callConfig,
        PositionStore.RequestIncrease memory request,
        TraderCallParams calldata traderCallParams,
        address[] calldata puppetList
    ) internal {
        address subaccount = address(callConfig.subaccountStore.getSubaccount(request.trader));

        if (subaccount == address(0)) {
            subaccount = address(callConfig.subaccountFactory.createSubaccount(callConfig.subaccountStore, request.trader));
        }

        bytes32 positionKey =
            GmxPositionUtils.getPositionKey(subaccount, traderCallParams.market, traderCallParams.collateralToken, traderCallParams.isLong);

        PositionStore.MirrorPosition memory mirrorPosition = callConfig.positionStore.getMirrorPosition(positionKey);

        if (puppetList.length > callConfig.limitPuppetList) revert RequestIncreasePosition__PuppetListLimitExceeded();

        (PuppetStore.Rule[] memory ruleList, uint[] memory activityList, uint[] memory allowanceList) =
            callConfig.puppetStore.getMatchingActivity(traderCallParams.collateralToken, request.trader, puppetList);

        CallParams memory callParams = CallParams({
            positionKey: positionKey,
            ruleList: ruleList,
            activityList: activityList,
            sampledAllowanceList: allowanceList,
            subaccountAddress: subaccount
        });

        if (mirrorPosition.size == 0) {
            open(callConfig, request, callParams, traderCallParams, puppetList);
        } else {
            adjust(callConfig, request, mirrorPosition, callParams, traderCallParams);
        }
    }

    function open(
        CallConfig memory callConfig,
        PositionStore.RequestIncrease memory request,
        CallParams memory callParams,
        TraderCallParams calldata traderCallParams,
        address[] calldata puppetList
    ) internal {
        if (puppetList.length > callConfig.limitPuppetList) revert RequestIncreasePosition__PuppetListLimitExceeded();

        uint sizeDeltaMultiplier = Precision.toBasisPoints(traderCallParams.sizeDelta, traderCallParams.collateralDelta);

        for (uint i = 0; i < puppetList.length; i++) {
            PuppetStore.Rule memory rule = callParams.ruleList[i];

            if (
                rule.expiry < block.timestamp // filter out frequent deposit activity. defined during rule setup
                    || callParams.activityList[i] + rule.throttleActivity > block.timestamp // expired rule. acounted every increase deposit
                    || callParams.sampledAllowanceList[i] < callConfig.minimumMatchAmount // not enough allowance
            ) continue;

            uint amountIn = Math.min( // the lowest of either the allowance or the trader's deposit
                Precision.applyBasisPoints(callParams.sampledAllowanceList[i], rule.allowanceRate),
                traderCallParams.collateralDelta // trader own deposit
            );

            if (!sendTokenOptimistically(callConfig, traderCallParams.collateralToken, puppetList[i])) {
                callParams.sampledAllowanceList[i] = 0;
                continue;
            }

            callParams.sampledAllowanceList[i] -= amountIn;

            request.puppetCollateralDeltaList[i] = amountIn;
            request.collateralDelta += amountIn;
            request.sizeDelta += Precision.applyBasisPoints(amountIn, sizeDeltaMultiplier);

            callParams.activityList[i] = block.timestamp;
        }

        callConfig.puppetRouter.setMatchingActivity(
            traderCallParams.collateralToken, request.trader, puppetList, callParams.activityList, callParams.sampledAllowanceList
        );

        bytes32 requestKey = _createOrder(callConfig, callParams, request, traderCallParams);

        request.transactionCost = (request.transactionCost - gasleft()) * tx.gasprice + traderCallParams.executionFee;
        callConfig.positionStore.setRequestIncrease(requestKey, request);

        emit RequestIncreasePosition__Match(request.trader, callParams.subaccountAddress, callParams.positionKey, requestKey, puppetList);
        emit RequestIncreasePosition__Request(
            request, callParams.subaccountAddress, callParams.positionKey, requestKey, traderCallParams.sizeDelta, traderCallParams.collateralDelta
        );
    }

    function adjust(
        CallConfig memory callConfig,
        PositionStore.RequestIncrease memory request,
        PositionStore.MirrorPosition memory mirrorPosition,
        CallParams memory callParams,
        TraderCallParams calldata traderCallParams
    ) internal {
        uint puppetLength = mirrorPosition.puppetList.length;

        if (puppetLength == 0) return;

        uint sizeDeltaMultiplier = Precision.toBasisPoints(traderCallParams.sizeDelta, traderCallParams.collateralDelta);
        uint mpLeverage = Precision.toBasisPoints(mirrorPosition.size, mirrorPosition.collateral);
        uint mpTargetLeverage = Precision.toBasisPoints(
            mirrorPosition.size + traderCallParams.sizeDelta, //
            mirrorPosition.collateral + traderCallParams.collateralDelta
        );
        uint puppetReduceSizeDelta;

        for (uint i = 0; i < mirrorPosition.puppetList.length; i++) {
            // did not match initial deposit
            if (mirrorPosition.puppetDepositList[i] == 0) continue;

            PuppetStore.Rule memory rule = callParams.ruleList[i];

            uint collateralDelta = mirrorPosition.puppetDepositList[i] * traderCallParams.collateralDelta / mirrorPosition.collateral;

            bool isIncrease = rule.expiry > block.timestamp // filter out frequent deposit activity. defined during rule setup
                || callParams.activityList[i] + rule.throttleActivity < block.timestamp // expired rule. acounted every increase deposit
                || callParams.sampledAllowanceList[i] > collateralDelta; // not enough allowance

            if (
                isIncrease
                    && sendTokenOptimistically(
                        callConfig.router,
                        traderCallParams.collateralToken,
                        callConfig.tokenTransferGasLimit,
                        mirrorPosition.puppetList[i],
                        callConfig.positionRouterAddress,
                        collateralDelta
                    )
            ) {
                callParams.sampledAllowanceList[i] -= collateralDelta;
                request.puppetCollateralDeltaList[i] += collateralDelta;
                request.collateralDelta += collateralDelta;
                request.sizeDelta += Precision.applyBasisPoints(collateralDelta, sizeDeltaMultiplier);
                callParams.activityList[i] = block.timestamp;

                continue;
            } else {
                // allowance sampling mismatched, likley out of sync. prevent future matching
                callParams.sampledAllowanceList[i] = 0;
            }

            if (mpTargetLeverage > mpLeverage) {
                uint deltaLeverage = mpTargetLeverage - mpLeverage;

                request.sizeDelta += mirrorPosition.size * deltaLeverage / mpTargetLeverage;
            } else {
                uint deltaLeverage = mpLeverage - mpTargetLeverage;

                puppetReduceSizeDelta += mirrorPosition.size * deltaLeverage / mpLeverage;
            }
        }

        callConfig.puppetRouter.setMatchingActivity(
            traderCallParams.collateralToken, request.trader, mirrorPosition.puppetList, callParams.activityList, callParams.sampledAllowanceList
        );

        bytes32 requestKey;

        // if the puppet size delta is greater than the overall required size incer, increase the puppet size delta
        if (request.sizeDelta > puppetReduceSizeDelta) {
            request.sizeDelta -= puppetReduceSizeDelta;
            requestKey = _createOrder(callConfig, callParams, request, traderCallParams);
        } else {
            request.sizeDelta = puppetReduceSizeDelta - request.sizeDelta;
            bytes32 reduceKey = _reducePuppetSizeDelta(callConfig, traderCallParams, callParams.subaccountAddress, puppetReduceSizeDelta);
            requestKey = _createOrder(callConfig, callParams, request, traderCallParams);
            callConfig.positionStore.setRequestIncrease(reduceKey, request);

            emit RequestIncreasePosition__RequestReducePuppetSize(
                request.trader, callParams.subaccountAddress, requestKey, reduceKey, puppetReduceSizeDelta
            );
        }

        callConfig.positionStore.setRequestIncrease(requestKey, request);

        emit RequestIncreasePosition__Request(
            request, callParams.subaccountAddress, callParams.positionKey, requestKey, traderCallParams.sizeDelta, traderCallParams.collateralDelta
        );
    }

    function _createOrder(
        CallConfig memory callConfig, //
        CallParams memory callParams,
        PositionStore.RequestIncrease memory request,
        TraderCallParams calldata traderCallParams
    ) internal returns (bytes32 requestKey) {
        GmxPositionUtils.CreateOrderParams memory orderParams = GmxPositionUtils.CreateOrderParams({
            addresses: GmxPositionUtils.CreateOrderParamsAddresses({
                receiver: callConfig.positionRouterAddress,
                callbackContract: callConfig.positionRouterAddress,
                uiFeeReceiver: address(0),
                market: traderCallParams.market,
                initialCollateralToken: traderCallParams.collateralToken,
                swapPath: new address[](0)
            }),
            numbers: GmxPositionUtils.CreateOrderParamsNumbers({
                initialCollateralDeltaAmount: request.collateralDelta,
                sizeDeltaUsd: request.sizeDelta,
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

        (bool orderSuccess, bytes memory orderReturnData) = Subaccount(callParams.subaccountAddress).execute(
            address(callConfig.gmxExchangeRouter), abi.encodeWithSelector(callConfig.gmxExchangeRouter.createOrder.selector, orderParams)
        );

        if (!orderSuccess) {
            ErrorUtils.revertWithParsedMessage(orderReturnData);
        }

        requestKey = abi.decode(orderReturnData, (bytes32));
    }

    function _reducePuppetSizeDelta(
        CallConfig memory callConfig, //
        TraderCallParams calldata traderCallparams,
        address subaccountAddress,
        uint puppetReduceSizeDelta
    ) internal returns (bytes32 requestKey) {
        GmxPositionUtils.CreateOrderParams memory params = GmxPositionUtils.CreateOrderParams({
            addresses: GmxPositionUtils.CreateOrderParamsAddresses({
                receiver: callConfig.positionRouterAddress,
                callbackContract: callConfig.positionRouterAddress,
                uiFeeReceiver: address(0),
                market: traderCallparams.market,
                initialCollateralToken: traderCallparams.collateralToken,
                swapPath: new address[](0)
            }),
            numbers: GmxPositionUtils.CreateOrderParamsNumbers({
                initialCollateralDeltaAmount: 0,
                sizeDeltaUsd: puppetReduceSizeDelta,
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

        (bool orderSuccess, bytes memory orderReturnData) = Subaccount(subaccountAddress).execute(
            address(callConfig.gmxExchangeRouter), abi.encodeWithSelector(callConfig.gmxExchangeRouter.createOrder.selector, params)
        );
        if (!orderSuccess) ErrorUtils.revertWithParsedMessage(orderReturnData);

        requestKey = abi.decode(orderReturnData, (bytes32));
    }

    // non reverting token transfer, return amount transferred
    function sendTokenOptimistically(Router router, IERC20 token, uint gasLimit, address from, address to, uint amount) internal returns (bool) {
        (bool success, bytes memory returndata) = router.rawTransfer{gas: gasLimit}(token, from, to, amount);

        return success && returndata.length == 0 && abi.decode(returndata, (bool));
    }

    error RequestIncreasePosition__PuppetListLimitExceeded();
    error RequestIncreasePosition__AddressListLengthMismatch();
    error RequestIncreasePosition__PositionAlreadyExists();
    error RequestIncreasePosition__PositionDoesNotExists();
    error RequestIncreasePosition__UnauthorizedSubaccountAccess();
}
