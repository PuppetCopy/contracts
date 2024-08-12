// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {IGmxExchangeRouter} from "./../interface/IGmxExchangeRouter.sol";

import {Precision} from "./../../utils/Precision.sol";
import {IWNT} from "./../../utils/interfaces/IWNT.sol";
import {ErrorUtils} from "./../../utils/ErrorUtils.sol";
import {GmxPositionUtils} from "../utils/GmxPositionUtils.sol";
import {PositionUtils} from "./../utils/PositionUtils.sol";
import {TransferUtils} from "./../../utils/TransferUtils.sol";

import {Router} from "./../../shared/Router.sol";
import {Subaccount} from "./../../shared/Subaccount.sol";
import {SubaccountStore} from "./../../shared/store/SubaccountStore.sol";
import {PuppetStore} from "./../../puppet/store/PuppetStore.sol";
import {PositionStore} from "../store/PositionStore.sol";

library RequestIncreasePosition {
    event RequestIncreasePosition__Match(address trader, address subaccount, bytes32 positionKey, bytes32 requestKey, address[] puppetList);
    event RequestIncreasePosition__Request(
        PositionStore.RequestAdjustment request,
        address subaccount,
        bytes32 positionKey,
        bytes32 requestKey,
        uint sizeDelta,
        uint collateralDelta,
        uint[] puppetCollateralDeltaList
    );

    event RequestIncreasePosition__RequestReducePuppetSize(
        address trader, address subaccount, bytes32 requestKey, bytes32 reduceRequestKey, uint sizeDelta
    );

    struct CallConfig {
        IWNT wnt;
        IGmxExchangeRouter gmxExchangeRouter;
        Router router;
        SubaccountStore subaccountStore;
        PositionStore positionStore;
        PuppetStore puppetStore;
        address gmxOrderReciever;
        address gmxOrderVault;
        bytes32 referralCode;
        uint callbackGasLimit;
        uint limitPuppetList;
        uint minimumMatchAmount;
        uint tokenTransferGasLimit;
    }

    struct MatchCallParams {
        address subaccountAddress;
        bytes32 positionKey;
        PuppetStore.Rule[] ruleList;
        uint[] activityList;
        uint[] balanceList;
        uint puppetLength;
        uint sizeDeltaMultiplier;
    }

    struct AdjustCallParams {
        address subaccountAddress;
        bytes32 positionKey;
        PuppetStore.Rule[] ruleList;
        uint[] activityList;
        uint[] depositList;
        uint puppetLength;
        uint sizeDeltaMultiplier;
        uint mpLeverage;
        uint mpTargetLeverage;
        uint puppetReduceSizeDelta;
    }

    function proxyIncrease(
        CallConfig memory callConfig, //
        PositionUtils.TraderCallParams calldata traderCallParams,
        address[] calldata puppetList
    ) internal {
        uint startGas = gasleft();

        PositionStore.RequestAdjustment memory request = PositionStore.RequestAdjustment({
            puppetCollateralDeltaList: new uint[](puppetList.length),
            collateralDelta: 0,
            sizeDelta: 0,
            transactionCost: startGas
        });

        increase(callConfig, request, traderCallParams, puppetList);
    }

    function traderIncrease(
        CallConfig memory callConfig, //
        PositionUtils.TraderCallParams calldata traderCallParams,
        address[] calldata puppetList
    ) internal {
        uint startGas = gasleft();
        PositionStore.RequestAdjustment memory request = PositionStore.RequestAdjustment({
            puppetCollateralDeltaList: new uint[](puppetList.length),
            collateralDelta: traderCallParams.collateralDelta,
            sizeDelta: traderCallParams.sizeDelta,
            transactionCost: startGas
        });

        // native ETH can be identified by depositing more than the execution fee
        if (address(traderCallParams.collateralToken) == address(callConfig.wnt) && traderCallParams.executionFee > msg.value) {
            TransferUtils.depositAndSendWnt(
                callConfig.wnt,
                address(callConfig.positionStore),
                callConfig.tokenTransferGasLimit,
                callConfig.gmxOrderVault,
                traderCallParams.executionFee + traderCallParams.collateralDelta
            );
        } else {
            TransferUtils.depositAndSendWnt(
                callConfig.wnt,
                address(callConfig.positionStore),
                callConfig.tokenTransferGasLimit,
                callConfig.gmxOrderVault,
                traderCallParams.executionFee
            );

            callConfig.router.transfer(
                traderCallParams.collateralToken, //
                traderCallParams.account,
                callConfig.gmxOrderVault,
                traderCallParams.collateralDelta
            );
        }

        increase(callConfig, request, traderCallParams, puppetList);
    }

    function increase(
        CallConfig memory callConfig,
        PositionStore.RequestAdjustment memory request,
        PositionUtils.TraderCallParams calldata traderCallParams,
        address[] calldata puppetList
    ) internal {
        address subaccountAddress = address(callConfig.subaccountStore.getSubaccount(traderCallParams.account));

        if (subaccountAddress == address(0)) {
            subaccountAddress = address(callConfig.subaccountStore.setSubaccount(traderCallParams.account));
        }

        bytes32 positionKey = GmxPositionUtils.getPositionKey(
            subaccountAddress, //
            traderCallParams.market,
            traderCallParams.collateralToken,
            traderCallParams.isLong
        );

        PositionStore.MirrorPosition memory mirrorPosition = callConfig.positionStore.getMirrorPosition(positionKey);

        (PuppetStore.Rule[] memory ruleList, uint[] memory activityList, uint[] memory balanceList) =
            callConfig.puppetStore.getBalanceAndActivityList(traderCallParams.collateralToken, traderCallParams.account, puppetList);

        if (mirrorPosition.size == 0) {
            MatchCallParams memory callParams = MatchCallParams({
                subaccountAddress: subaccountAddress,
                positionKey: positionKey,
                ruleList: ruleList,
                activityList: activityList,
                balanceList: balanceList,
                puppetLength: puppetList.length,
                sizeDeltaMultiplier: Precision.toBasisPoints(traderCallParams.sizeDelta, traderCallParams.collateralDelta)
            });

            matchUp(callConfig, request, callParams, traderCallParams, puppetList);
        } else {
            request.puppetCollateralDeltaList = new uint[](mirrorPosition.puppetList.length);
            AdjustCallParams memory callParams = AdjustCallParams({
                subaccountAddress: subaccountAddress,
                positionKey: positionKey,
                ruleList: ruleList,
                activityList: activityList,
                depositList: balanceList,
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
        PositionUtils.TraderCallParams calldata traderCallParams,
        address[] calldata puppetList
    ) internal {
        PositionStore.RequestMatch memory requestMatch = callConfig.positionStore.getRequestMatch(callParams.positionKey);

        if (requestMatch.trader != address(0)) revert RequestIncreasePosition__MatchRequestPending();
        if (callParams.puppetLength > callConfig.limitPuppetList) revert RequestIncreasePosition__PuppetListLimitExceeded();

        requestMatch = PositionStore.RequestMatch({trader: traderCallParams.account, puppetList: puppetList});

        for (uint i = 0; i < callParams.puppetLength; i++) {
            // validate that puppet list calldata is sorted and has no duplicates
            if (i > 0) {
                if (puppetList[i - 1] > puppetList[i]) revert RequestIncreasePosition__UnsortedPuppetList();
                if (puppetList[i - 1] == puppetList[i]) revert RequestIncreasePosition__DuplicatesInPuppetList();
            }

            PuppetStore.Rule memory rule = callParams.ruleList[i];

            if (
                rule.expiry > block.timestamp // puppet rule expired or not set
                    || callParams.activityList[i] + rule.throttleActivity < block.timestamp // current time is greater than throttle activity period
                    || callParams.balanceList[i] > callConfig.minimumMatchAmount // has enough allowance or token allowance cap exists
            ) {
                // the lowest of either the allowance or the trader's deposit
                uint collateralDelta = Math.min(
                    Precision.applyBasisPoints(rule.allowanceRate, callParams.balanceList[i]),
                    traderCallParams.collateralDelta // trader own deposit
                );
                callParams.balanceList[i] = collateralDelta;
                callParams.activityList[i] = block.timestamp;

                request.puppetCollateralDeltaList[i] = collateralDelta;
                request.collateralDelta += collateralDelta;
                request.sizeDelta += Precision.applyBasisPoints(callParams.sizeDeltaMultiplier, collateralDelta);
            }
        }

        callConfig.puppetStore.decreaseBalanceAndSetActivityList(
            traderCallParams.collateralToken, callConfig.gmxOrderVault, traderCallParams.account, block.timestamp, puppetList, callParams.balanceList
        );
        callConfig.positionStore.setRequestMatch(callParams.positionKey, requestMatch);

        bytes32 requestKey = _createOrder(callConfig, request, traderCallParams, callParams.subaccountAddress, callParams.positionKey);

        emit RequestIncreasePosition__Match(traderCallParams.account, callParams.subaccountAddress, callParams.positionKey, requestKey, puppetList);
    }

    function adjust(
        CallConfig memory callConfig,
        PositionStore.RequestAdjustment memory request,
        PositionStore.MirrorPosition memory mirrorPosition,
        AdjustCallParams memory callParams,
        PositionUtils.TraderCallParams calldata traderCallParams
    ) internal {
        for (uint i = 0; i < callParams.puppetLength; i++) {
            // did not match initially
            if (mirrorPosition.collateralList[i] == 0) continue;

            PuppetStore.Rule memory rule = callParams.ruleList[i];

            uint collateralDelta = mirrorPosition.collateralList[i] * traderCallParams.collateralDelta / mirrorPosition.collateral;

            if (
                rule.expiry > block.timestamp // filter out frequent deposit activity
                    || callParams.activityList[i] + rule.throttleActivity < block.timestamp // expired rule. acounted every increase deposit
                    || callParams.depositList[i] > collateralDelta
            ) {
                callParams.depositList[i] -= collateralDelta;
                callParams.activityList[i] = block.timestamp;

                request.puppetCollateralDeltaList[i] += collateralDelta;
                request.collateralDelta += collateralDelta;
                request.sizeDelta += Precision.applyBasisPoints(callParams.sizeDeltaMultiplier, collateralDelta);
            } else if (callParams.mpTargetLeverage > callParams.mpLeverage) {
                uint deltaLeverage = callParams.mpTargetLeverage - callParams.mpLeverage;

                request.sizeDelta += mirrorPosition.size * deltaLeverage / callParams.mpTargetLeverage;
            } else {
                uint deltaLeverage = callParams.mpLeverage - callParams.mpTargetLeverage;

                callParams.puppetReduceSizeDelta += mirrorPosition.size * deltaLeverage / callParams.mpLeverage;
            }
        }

        bytes32 requestKey;

        callConfig.puppetStore.decreaseBalanceAndSetActivityList(
            traderCallParams.collateralToken,
            callConfig.gmxOrderVault,
            traderCallParams.account,
            block.timestamp,
            mirrorPosition.puppetList,
            callParams.depositList
        );

        // if the puppet size delta is greater than the overall request size, decrease the puppet size delta in a separate request
        if (callParams.puppetReduceSizeDelta > request.sizeDelta) {
            request.sizeDelta = callParams.puppetReduceSizeDelta - request.sizeDelta;

            if (request.collateralDelta > 0 && request.sizeDelta > 0) {
                requestKey = _createOrder(callConfig, request, traderCallParams, callParams.subaccountAddress, callParams.positionKey);
            }

            bytes32 reduceKey = _reducePuppetSizeDelta(callConfig, traderCallParams, callParams.subaccountAddress, callParams.puppetReduceSizeDelta);
            callConfig.positionStore.setRequestAdjustment(reduceKey, request);
        } else {
            request.sizeDelta -= callParams.puppetReduceSizeDelta;
            requestKey = _createOrder(callConfig, request, traderCallParams, callParams.subaccountAddress, callParams.positionKey);
        }
    }

    function _createOrder(
        CallConfig memory callConfig, //
        PositionStore.RequestAdjustment memory request,
        PositionUtils.TraderCallParams calldata traderCallParams,
        address subaccountAddress,
        bytes32 positionKey
    ) internal returns (bytes32 requestKey) {
        GmxPositionUtils.CreateOrderParams memory orderParams = GmxPositionUtils.CreateOrderParams({
            addresses: GmxPositionUtils.CreateOrderParamsAddresses({
                receiver: callConfig.gmxOrderReciever,
                callbackContract: address(this),
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

        request.transactionCost = (request.transactionCost - gasleft()) * tx.gasprice + traderCallParams.executionFee;
        callConfig.positionStore.setRequestAdjustment(requestKey, request);

        emit RequestIncreasePosition__Request(
            request,
            subaccountAddress,
            positionKey,
            requestKey,
            traderCallParams.sizeDelta,
            traderCallParams.collateralDelta,
            request.puppetCollateralDeltaList
        );
    }

    function _reducePuppetSizeDelta(
        CallConfig memory callConfig, //
        PositionUtils.TraderCallParams calldata traderCallParams,
        address subaccountAddress,
        uint puppetReduceSizeDelta
    ) internal returns (bytes32 requestKey) {
        GmxPositionUtils.CreateOrderParams memory params = GmxPositionUtils.CreateOrderParams({
            addresses: GmxPositionUtils.CreateOrderParamsAddresses({
                receiver: callConfig.gmxOrderReciever,
                callbackContract: address(this),
                uiFeeReceiver: address(0),
                market: traderCallParams.market,
                initialCollateralToken: traderCallParams.collateralToken,
                swapPath: new address[](0)
            }),
            numbers: GmxPositionUtils.CreateOrderParamsNumbers({
                initialCollateralDeltaAmount: 0,
                sizeDeltaUsd: puppetReduceSizeDelta,
                triggerPrice: traderCallParams.triggerPrice,
                acceptablePrice: traderCallParams.acceptablePrice,
                executionFee: traderCallParams.executionFee,
                callbackGasLimit: callConfig.callbackGasLimit,
                minOutputAmount: 0
            }),
            orderType: GmxPositionUtils.OrderType.MarketDecrease,
            decreasePositionSwapType: GmxPositionUtils.DecreasePositionSwapType.NoSwap,
            isLong: traderCallParams.isLong,
            shouldUnwrapNativeToken: false,
            referralCode: callConfig.referralCode
        });

        (bool orderSuccess, bytes memory orderReturnData) = Subaccount(subaccountAddress).execute(
            address(callConfig.gmxExchangeRouter), abi.encodeWithSelector(callConfig.gmxExchangeRouter.createOrder.selector, params)
        );
        if (!orderSuccess) ErrorUtils.revertWithParsedMessage(orderReturnData);

        requestKey = abi.decode(orderReturnData, (bytes32));

        emit RequestIncreasePosition__RequestReducePuppetSize(
            traderCallParams.account, subaccountAddress, requestKey, requestKey, puppetReduceSizeDelta
        );
    }

    error RequestIncreasePosition__PuppetListLimitExceeded();
    error RequestIncreasePosition__MatchRequestPending();
    error RequestIncreasePosition__UnsortedPuppetList();
    error RequestIncreasePosition__DuplicatesInPuppetList();
}
