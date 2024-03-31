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
        PositionStore.RequestAdjustment request,
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

    struct MatchCallParams {
        address subaccountAddress;
        bytes32 positionKey;
        PuppetStore.Rule[] ruleList;
        uint[] activityList;
        uint[] sampledAllowanceList;
        uint puppetLength;
        uint sizeDeltaMultiplier;
    }

    struct AdjustCallParams {
        address subaccountAddress;
        bytes32 positionKey;
        PuppetStore.Rule[] ruleList;
        uint[] activityList;
        uint[] sampledAllowanceList;
        uint puppetLength;
        uint sizeDeltaMultiplier;
        uint mpLeverage;
        uint mpTargetLeverage;
        uint puppetReduceSizeDelta;
    }

    function increase(
        CallConfig memory callConfig,
        PositionStore.RequestAdjustment memory request,
        TraderCallParams calldata traderCallParams,
        address[] calldata puppetList
    ) internal {
        address subaccountAddress = address(callConfig.subaccountStore.getSubaccount(request.trader));

        if (subaccountAddress == address(0)) {
            subaccountAddress = address(callConfig.subaccountFactory.createSubaccount(callConfig.subaccountStore, request.trader));
        }

        bytes32 positionKey =
            GmxPositionUtils.getPositionKey(subaccountAddress, traderCallParams.market, traderCallParams.collateralToken, traderCallParams.isLong);

        PositionStore.MirrorPosition memory mirrorPosition = callConfig.positionStore.getMirrorPosition(positionKey);

        (PuppetStore.Rule[] memory ruleList, uint[] memory activityList, uint[] memory allowanceList) =
            callConfig.puppetStore.getMatchingActivity(traderCallParams.collateralToken, request.trader, puppetList);

        if (mirrorPosition.size == 0) {
            MatchCallParams memory callParams = MatchCallParams({
                positionKey: positionKey,
                ruleList: ruleList,
                activityList: activityList,
                sampledAllowanceList: allowanceList,
                subaccountAddress: subaccountAddress,
                puppetLength: puppetList.length,
                sizeDeltaMultiplier: Precision.toBasisPoints(traderCallParams.sizeDelta, traderCallParams.collateralDelta)
            });

            matchUp(callConfig, request, callParams, traderCallParams, puppetList);
        } else {
            AdjustCallParams memory callParams = AdjustCallParams({
                subaccountAddress: subaccountAddress,
                positionKey: positionKey,
                ruleList: ruleList,
                activityList: activityList,
                sampledAllowanceList: allowanceList,
                puppetLength: mirrorPosition.puppetList.length,
                sizeDeltaMultiplier: Precision.toBasisPoints(traderCallParams.sizeDelta, traderCallParams.collateralDelta),
                mpLeverage: Precision.toBasisPoints(mirrorPosition.size, mirrorPosition.collateral),
                mpTargetLeverage: Precision.toBasisPoints(
                    mirrorPosition.size + traderCallParams.sizeDelta, //
                    mirrorPosition.collateral + traderCallParams.collateralDelta
                    ),
                puppetReduceSizeDelta: 0
            });

            adjust(callConfig, request, mirrorPosition, callParams, traderCallParams);
        }
    }

    function matchUp(
        CallConfig memory callConfig,
        PositionStore.RequestAdjustment memory request,
        MatchCallParams memory callParams,
        TraderCallParams calldata traderCallParams,
        address[] calldata puppetList
    ) internal {
        PositionStore.RequestMatch memory requestMatch = callConfig.positionStore.getRequestMatch(callParams.positionKey);

        if (requestMatch.trader != address(0)) revert RequestIncreasePosition__MatchRequestPending();

        requestMatch = PositionStore.RequestMatch({trader: request.trader, puppetList: puppetList});

        if (puppetList.length > callConfig.limitPuppetList) revert RequestIncreasePosition__PuppetListLimitExceeded();

        for (uint i = 0; i < puppetList.length; i++) {
            PuppetStore.Rule memory rule = callParams.ruleList[i];

            // the lowest of either the allowance or the trader's deposit
            uint amountIn = Math.min(
                Precision.applyBasisPoints(callParams.sampledAllowanceList[i], rule.allowanceRate),
                traderCallParams.collateralDelta // trader own deposit
            );

            bool isMatched = rule.expiry > block.timestamp // puppet rule expired or not set
                || callParams.activityList[i] + rule.throttleActivity < block.timestamp // current time is greater than throttle activity period
                || callParams.sampledAllowanceList[i] < callConfig.minimumMatchAmount; // has enough allowance or token allowance cap exists

            if (isMatched) {
                if (
                    sendTokenOptimistically(
                        callConfig.router,
                        traderCallParams.collateralToken,
                        callConfig.tokenTransferGasLimit,
                        puppetList[i],
                        callConfig.positionRouterAddress,
                        amountIn
                    )
                ) {
                    callParams.sampledAllowanceList[i] -= amountIn;
                    callParams.activityList[i] = block.timestamp;

                    request.puppetCollateralDeltaList[i] = amountIn;
                    request.collateralDelta += amountIn;
                    request.sizeDelta += Precision.applyBasisPoints(amountIn, callParams.sizeDeltaMultiplier);

                    continue;
                } else {
                    callParams.sampledAllowanceList[i] = 0;
                }
            }
        }

        bytes32 requestKey = _createOrder(callConfig, request, traderCallParams, callParams.subaccountAddress);

        callConfig.puppetRouter.setMatchingActivity(
            traderCallParams.collateralToken, request.trader, puppetList, callParams.activityList, callParams.sampledAllowanceList
        );
        callConfig.positionStore.setRequestMatch(callParams.positionKey, requestMatch);

        request.transactionCost = (request.transactionCost - gasleft()) * tx.gasprice + traderCallParams.executionFee;
        callConfig.positionStore.setRequestAdjustment(requestKey, request);

        emit RequestIncreasePosition__Match(request.trader, callParams.subaccountAddress, callParams.positionKey, requestKey, puppetList);
        emit RequestIncreasePosition__Request(
            request, callParams.subaccountAddress, callParams.positionKey, requestKey, traderCallParams.sizeDelta, traderCallParams.collateralDelta
        );
    }

    function adjust(
        CallConfig memory callConfig,
        PositionStore.RequestAdjustment memory request,
        PositionStore.MirrorPosition memory mirrorPosition,
        AdjustCallParams memory callParams,
        TraderCallParams calldata traderCallParams
    ) internal {
        for (uint i = 0; i < callParams.puppetLength; i++) {
            // did not match initially
            if (mirrorPosition.collateralList[i] == 0) continue;

            PuppetStore.Rule memory rule = callParams.ruleList[i];

            uint collateralDelta = mirrorPosition.collateralList[i] * traderCallParams.collateralDelta / mirrorPosition.collateral;

            bool isIncrease = rule.expiry > block.timestamp // filter out frequent deposit activity. defined during rule setup
                || callParams.activityList[i] + rule.throttleActivity < block.timestamp // expired rule. acounted every increase deposit
                || callParams.sampledAllowanceList[i] > collateralDelta; // not enough allowance or

            if (isIncrease) {
                if (
                    sendTokenOptimistically(
                        callConfig.router,
                        traderCallParams.collateralToken,
                        callConfig.tokenTransferGasLimit,
                        mirrorPosition.puppetList[i],
                        callConfig.positionRouterAddress,
                        collateralDelta
                    )
                ) {
                    callParams.sampledAllowanceList[i] -= collateralDelta;
                    callParams.activityList[i] = block.timestamp;

                    request.puppetCollateralDeltaList[i] += collateralDelta;
                    request.collateralDelta += collateralDelta;
                    request.sizeDelta += Precision.applyBasisPoints(collateralDelta, callParams.sizeDeltaMultiplier);

                    continue;
                } else {
                    // allowance sampling mismatched, likley out of sync. prevent future matching and continue in reducing puppet size
                    callParams.sampledAllowanceList[i] = 0;
                }
            }

            if (callParams.mpTargetLeverage > callParams.mpLeverage) {
                uint deltaLeverage = callParams.mpTargetLeverage - callParams.mpLeverage;

                request.sizeDelta += mirrorPosition.size * deltaLeverage / callParams.mpTargetLeverage;
            } else {
                uint deltaLeverage = callParams.mpLeverage - callParams.mpTargetLeverage;

                callParams.puppetReduceSizeDelta += mirrorPosition.size * deltaLeverage / callParams.mpLeverage;
            }
        }

        bytes32 requestKey;

        // if the puppet size delta is greater than the overall required size incer, increase the puppet size delta
        if (request.sizeDelta > callParams.puppetReduceSizeDelta) {
            request.sizeDelta -= callParams.puppetReduceSizeDelta;
            requestKey = _createOrder(callConfig, request, traderCallParams, callParams.subaccountAddress);
        } else {
            bytes32 reduceKey = _reducePuppetSizeDelta(callConfig, traderCallParams, callParams.subaccountAddress, callParams.puppetReduceSizeDelta);

            request.sizeDelta = callParams.puppetReduceSizeDelta - request.sizeDelta;
            requestKey = _createOrder(callConfig, request, traderCallParams, callParams.subaccountAddress);
            callConfig.positionStore.setRequestAdjustment(reduceKey, request);

            emit RequestIncreasePosition__RequestReducePuppetSize(
                request.trader, callParams.subaccountAddress, requestKey, reduceKey, callParams.puppetReduceSizeDelta
            );
        }

        callConfig.puppetRouter.setMatchingActivity(
            traderCallParams.collateralToken, request.trader, mirrorPosition.puppetList, callParams.activityList, callParams.sampledAllowanceList
        );

        callConfig.positionStore.setRequestAdjustment(requestKey, request);

        emit RequestIncreasePosition__Request(
            request, callParams.subaccountAddress, callParams.positionKey, requestKey, traderCallParams.sizeDelta, traderCallParams.collateralDelta
        );
    }

    function _createOrder(
        CallConfig memory callConfig, //
        PositionStore.RequestAdjustment memory request,
        TraderCallParams calldata traderCallParams,
        address subaccountAddress
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

        (bool orderSuccess, bytes memory orderReturnData) = Subaccount(subaccountAddress).execute(
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
    error RequestIncreasePosition__MatchRequestPending();
}
