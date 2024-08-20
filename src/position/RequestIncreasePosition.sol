// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {Permission} from "../utils/access/Permission.sol";

import {IGmxExchangeRouter} from "./interface/IGmxExchangeRouter.sol";

import {Precision} from "./../utils/Precision.sol";
import {IWNT} from "./../utils/interfaces/IWNT.sol";
import {ErrorUtils} from "./../utils/ErrorUtils.sol";
import {GmxPositionUtils} from "./utils/GmxPositionUtils.sol";
import {PositionUtils} from "./utils/PositionUtils.sol";
import {TransferUtils} from "./../utils/TransferUtils.sol";

import {Router} from "./../shared/Router.sol";
import {Subaccount} from "./../shared/Subaccount.sol";
import {SubaccountStore} from "./../shared/store/SubaccountStore.sol";
import {PuppetStore} from "./../puppet/store/PuppetStore.sol";
import {PositionStore} from "./store/PositionStore.sol";

contract RequestIncreasePosition is Permission, EIP712 {
    event RequestIncreasePosition__SetConfig(uint timestamp, CallConfig callConfig);

    event RequestIncreasePosition__Match(
        address trader,
        address subaccount,
        bytes32 positionKey,
        bytes32 requestKey,
        address[] puppetList
    );
    event RequestIncreasePosition__Adjust(
        address trader,
        address subaccount,
        //
        bytes32 positionKey,
        bytes32 requestKey,
        uint[] puppetCollateralDeltaList,
        uint transactionCost
    );
    event RequestIncreasePosition__ReducePuppetSize(
        address trader,
        //
        address subaccount,
        bytes32 positionKey,
        bytes32 requestKey,
        uint sizeDelta
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
        PuppetStore.Rule[] ruleList;
        uint[] activityList;
        uint[] balanceList;
        uint puppetLength;
        uint sizeDeltaMultiplier;
    }

    struct AdjustCallParams {
        address subaccountAddress;
        PuppetStore.Rule[] ruleList;
        uint[] activityList;
        uint[] depositList;
        uint puppetLength;
        uint sizeDeltaMultiplier;
        uint mpLeverage;
        uint mpTargetLeverage;
        uint puppetReduceSizeDelta;
    }

    CallConfig callConfig;

    constructor(IAuthority _authority, CallConfig memory _callConfig) Permission(_authority) EIP712("RequestIncreasePosition", "1") {
        _setConfig(_callConfig);
    }

    function proxyIncrease(
        PositionUtils.TraderCallParams calldata traderCallParams, //
        address[] calldata puppetList,
        address user
    ) external payable auth {
        uint startGas = gasleft();

        address subaccountAddress = address(callConfig.subaccountStore.getSubaccount(user));

        PositionStore.RequestAdjustment memory request = PositionStore.RequestAdjustment({
            positionKey: GmxPositionUtils.getPositionKey(
                subaccountAddress, //
                traderCallParams.market,
                traderCallParams.collateralToken,
                traderCallParams.isLong
                ),
            collateralDeltaList: new uint[](puppetList.length),
            collateralDelta: 0,
            sizeDelta: 0,
            transactionCost: startGas
        });

        increase(request, traderCallParams, puppetList, subaccountAddress);
    }

    function traderIncrease(
        PositionUtils.TraderCallParams calldata traderCallParams, //
        address[] calldata puppetList,
        address user
    ) external payable auth {
        uint startGas = gasleft();
        if (traderCallParams.account != user) revert RequestIncreasePosition__SenderNotMatchingTrader();

        address subaccountAddress = address(callConfig.subaccountStore.getSubaccount(traderCallParams.account));

        PositionStore.RequestAdjustment memory request = PositionStore.RequestAdjustment({
            positionKey: GmxPositionUtils.getPositionKey(
                subaccountAddress, //
                traderCallParams.market,
                traderCallParams.collateralToken,
                traderCallParams.isLong
                ),
            collateralDeltaList: new uint[](puppetList.length),
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

        increase(request, traderCallParams, puppetList, subaccountAddress);
    }

    function increase(
        PositionStore.RequestAdjustment memory request,
        PositionUtils.TraderCallParams calldata traderCallParams,
        address[] calldata puppetList,
        address subaccountAddress
    ) internal {
        if (subaccountAddress == address(0)) {
            subaccountAddress = address(callConfig.subaccountStore.setSubaccount(traderCallParams.account));
        }

        PositionStore.MirrorPosition memory mirrorPosition = callConfig.positionStore.getMirrorPosition(request.positionKey);

        (PuppetStore.Rule[] memory ruleList, uint[] memory activityList, uint[] memory balanceList) =
            callConfig.puppetStore.getBalanceAndActivityList(traderCallParams.collateralToken, traderCallParams.account, puppetList);

        if (mirrorPosition.size == 0) {
            MatchCallParams memory callParams = MatchCallParams({
                subaccountAddress: subaccountAddress,
                ruleList: ruleList,
                activityList: activityList,
                balanceList: balanceList,
                puppetLength: puppetList.length,
                sizeDeltaMultiplier: Precision.toBasisPoints(traderCallParams.sizeDelta, traderCallParams.collateralDelta)
            });

            matchUp(request, callParams, traderCallParams, puppetList);
        } else {
            request.collateralDeltaList = new uint[](mirrorPosition.puppetList.length);
            AdjustCallParams memory callParams = AdjustCallParams({
                subaccountAddress: subaccountAddress,
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

            adjust(request, mirrorPosition, callParams, traderCallParams);
        }
    }

    function matchUp(
        PositionStore.RequestAdjustment memory request, //
        MatchCallParams memory callParams,
        PositionUtils.TraderCallParams calldata traderCallParams,
        address[] calldata puppetList
    ) internal {
        PositionStore.RequestMatch memory requestMatch = callConfig.positionStore.getRequestMatch(request.positionKey);

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

                request.collateralDeltaList[i] = collateralDelta;
                request.collateralDelta += collateralDelta;
                request.sizeDelta += Precision.applyBasisPoints(callParams.sizeDeltaMultiplier, collateralDelta);
            }
        }

        callConfig.puppetStore.decreaseBalanceAndSetActivityList(
            traderCallParams.collateralToken, callConfig.gmxOrderVault, traderCallParams.account, block.timestamp, puppetList, callParams.balanceList
        );
        callConfig.positionStore.setRequestMatch(request.positionKey, requestMatch);

        bytes32 requestKey = _createOrder(request, traderCallParams, callParams.subaccountAddress, request.positionKey);

        emit RequestIncreasePosition__Match(
            traderCallParams.account, //
            callParams.subaccountAddress,
            request.positionKey,
            requestKey,
            requestMatch.puppetList
        );
    }

    function adjust(
        PositionStore.RequestAdjustment memory request, //
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

                request.collateralDeltaList[i] += collateralDelta;
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

        // if the puppet size delta is greater than the overall request size delta, decrease the puppet size to match trader leverage ratio
        if (callParams.puppetReduceSizeDelta > request.sizeDelta) {
            request.sizeDelta = callParams.puppetReduceSizeDelta - request.sizeDelta;

            if (request.collateralDelta > 0 && request.sizeDelta > 0) {
                requestKey = _createOrder(request, traderCallParams, callParams.subaccountAddress, request.positionKey);
            }

            bytes32 requestReduceKey =
                _reducePuppetSizeDelta(traderCallParams, callParams.subaccountAddress, callParams.puppetReduceSizeDelta, request.positionKey);
            callConfig.positionStore.setRequestAdjustment(requestReduceKey, request);
        } else {
            request.sizeDelta -= callParams.puppetReduceSizeDelta;
            requestKey = _createOrder(request, traderCallParams, callParams.subaccountAddress, request.positionKey);
        }
    }

    function _createOrder(
        PositionStore.RequestAdjustment memory request, //
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

        emit RequestIncreasePosition__Adjust(
            traderCallParams.account, //
            subaccountAddress,
            //
            positionKey,
            requestKey,
            request.collateralDeltaList,
            request.transactionCost
        );
    }

    function _reducePuppetSizeDelta(
        PositionUtils.TraderCallParams calldata traderCallParams, //
        address subaccountAddress,
        uint puppetReduceSizeDelta,
        bytes32 positionKey
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

        emit RequestIncreasePosition__ReducePuppetSize(
            traderCallParams.account, subaccountAddress, positionKey, requestKey, puppetReduceSizeDelta
        );
    }

    // governance

    function setConfig(CallConfig memory _callConfig) external auth {
        _setConfig(_callConfig);
    }

    function _setConfig(CallConfig memory _callConfig) internal {
        callConfig = _callConfig;

        emit RequestIncreasePosition__SetConfig(block.timestamp, callConfig);
    }

    error RequestIncreasePosition__PuppetListLimitExceeded();
    error RequestIncreasePosition__MatchRequestPending();
    error RequestIncreasePosition__UnsortedPuppetList();
    error RequestIncreasePosition__DuplicatesInPuppetList();
    error RequestIncreasePosition__SenderNotMatchingTrader();
}
