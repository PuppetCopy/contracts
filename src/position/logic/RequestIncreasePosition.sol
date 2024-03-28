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
        uint minimumMatchAmount;
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
        uint[] activityList;
        uint[] optimisticAllowanceList;
        IERC20 collateralToken;
        Subaccount subaccount;
        bytes32 positionKey;
        address subaccountAddress;
        address positionStoreAddress;
        uint totalTransactionCost;
        uint reducePuppetSizeDelta;
        uint totalSizeDelta;
        uint totalCollateralDelta;
    }

    function increase(CallConfig memory callConfig, TraderCallParams calldata traderCallParams, address trader) internal {
        Subaccount subaccount = callConfig.subaccountStore.getSubaccount(trader);

        if (address(subaccount) == address(0)) {
            subaccount = callConfig.subaccountFactory.createSubaccount(callConfig.subaccountStore, trader);
        }

        RequestIncreasePosition.CallParams memory callParams = _getCallParams(callConfig, traderCallParams, trader, subaccount);
        PositionStore.RequestIncrease memory request = PositionStore.RequestIncrease({
            trader: trader,
            puppetCollateralDeltaList: new uint[](traderCallParams.puppetList.length),
            leverageTarget: 0,
            collateralDelta: traderCallParams.collateralDelta,
            sizeDelta: traderCallParams.sizeDelta
        });

        PositionStore.MirrorPosition memory mirrorPosition = callConfig.positionStore.getMirrorPosition(callParams.positionKey);

        if (mirrorPosition.size == 0) {
            request.leverageTarget = Precision.toBasisPoints(traderCallParams.sizeDelta, traderCallParams.collateralDelta);

            open(callConfig, callParams, request, traderCallParams);
        } else {
            request.leverageTarget = Precision.toBasisPoints(
                mirrorPosition.size + traderCallParams.sizeDelta, //
                mirrorPosition.collateral + traderCallParams.collateralDelta
            );

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

            uint amountIn = rule.expiry < block.timestamp // filter out frequent deposit activity. defined during rule setup
                || callParams.activityList[i] + rule.throttleActivity > block.timestamp // expired rule. acounted every increase deposit
                || callParams.optimisticAllowanceList[i] < callConfig.minimumMatchAmount // stop loss. accounted every reduce adjustment
                ? 0
                : sendTokenOptimistically(
                    callConfig,
                    callParams.collateralToken,
                    traderCallParams.puppetList[i],
                    callParams.positionStoreAddress,
                    Math.min( // the lowest of either the allowance or the trader's deposit
                        traderCallParams.sizeDelta / Precision.applyBasisPoints(callParams.optimisticAllowanceList[i], rule.allowanceRate),
                        traderCallParams.collateralDelta // trader own deposit
                    )
                );

            // avoid matching, update global allowance to avoid future matching
            if (amountIn == 0) {
                callParams.optimisticAllowanceList[i] = 0;
                continue;
            }

            request.puppetCollateralDeltaList[i] = amountIn;
            callParams.optimisticAllowanceList[i] -= amountIn;

            callParams.totalCollateralDelta += amountIn;
            callParams.totalSizeDelta += amountIn * request.leverageTarget / Precision.BASIS_POINT_DIVISOR;
            callParams.activityList[i] = block.timestamp;
        }

        // callConfig.puppetStore.setActivityList([callParams.routeKey], callParams.activityList);
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
        if (traderCallParams.puppetList.length > callConfig.limitPuppetList) revert RequestIncreasePosition__PuppetListLimitExceeded();

        for (uint i = 0; i < mirrorPosition.puppetList.length; i++) {
            PuppetStore.Rule memory rule = callParams.ruleList[i];

            uint amountIn = rule.expiry < block.timestamp // filter out frequent deposit activity. defined during rule setup
                || callParams.activityList[i] + rule.throttleActivity > block.timestamp // expired rule. acounted every increase deposit
                || mirrorPosition.puppetDepositList[i] == 0 // did not match initial deposit
                ? 0
                : sendTokenOptimistically(
                    callConfig,
                    callParams.collateralToken,
                    mirrorPosition.puppetList[i],
                    callParams.positionStoreAddress,
                    traderCallParams.sizeDelta / mirrorPosition.puppetDepositList[i]
                );

            uint sizeDelta = traderCallParams.sizeDelta * amountIn / mirrorPosition.size;
            // uint gasFee = amountIn * sizeDelta * Precision.BASIS_POINT_DIVISOR / traderCallParams.sizeDelta / Precision.BASIS_POINT_DIVISOR;

            if (amountIn > 0) {
                uint amountAfterFee = amountIn - PositionUtils.getPlatformMatchingFee(callConfig.platformFee, sizeDelta);

                request.puppetCollateralDeltaList[i] += amountAfterFee;
                callParams.totalSizeDelta += sizeDelta;
                callParams.totalCollateralDelta += amountAfterFee;

                callParams.activityList[i] = block.timestamp;
            } else {
                uint adjustedSizeDelta = sizeDelta * Precision.diff(request.leverageTarget, mirrorPosition.leverage) / mirrorPosition.leverage;
                if (request.leverageTarget > mirrorPosition.leverage) {
                    callParams.totalSizeDelta += adjustedSizeDelta;
                } else {
                    callParams.reducePuppetSizeDelta += adjustedSizeDelta;
                }
            }
        }

        // callConfig.puppetStore.setActivityList(callParams.routeKey, mirrorPosition.puppetList, callParams.activityList);
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
        // TODO: implement fee calculation
        // split between trader and puppet, take the double amount , later possibly reduced based on other puppets propotional contribution
        // uint transactionFee = callParams.totalTransactionCost * amountIn / traderCallParams.collateralDelta;
        // uint amountAfterFee = amountIn - PositionUtils.getPlatformMatchingFee(callConfig.platformFee, sizeDelta);

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
    function sendTokenOptimistically(CallConfig memory callConfig, IERC20 token, address trader, address to, uint amount) internal returns (uint) {
        (bool success, bytes memory returndata) = callConfig.router.rawTrasnfer{gas: callConfig.tokenTransferGasLimit}(token, trader, to, amount);

        if (success && returndata.length == 0 && abi.decode(returndata, (bool))) return amount;

        return 0;
    }

    function _getCallParams(CallConfig memory callConfig, TraderCallParams calldata traderCallParams, address trader, Subaccount subaccount)
        internal
        view
        returns (RequestIncreasePosition.CallParams memory)
    {
        bytes32 positionKey =
            GmxPositionUtils.getPositionKey(trader, traderCallParams.market, traderCallParams.collateralToken, traderCallParams.isLong);

        (PuppetStore.Rule[] memory ruleList, uint[] memory activityList, uint[] memory allowanceList) =
            callConfig.puppetStore.getRouteMatchingState(traderCallParams.collateralToken, trader, traderCallParams.puppetList);

        return RequestIncreasePosition.CallParams({
            ruleList: ruleList,
            activityList: activityList,
            optimisticAllowanceList: allowanceList,
            collateralToken: IERC20(traderCallParams.collateralToken),
            subaccount: subaccount,
            positionKey: positionKey,
            subaccountAddress: address(subaccount),
            positionStoreAddress: address(callConfig.positionStore),
            totalTransactionCost: gasleft() * tx.gasprice + traderCallParams.executionFee,
            reducePuppetSizeDelta: 0,
            totalCollateralDelta: traderCallParams.collateralDelta,
            totalSizeDelta: traderCallParams.sizeDelta
        });
    }

    error RequestIncreasePosition__PuppetListLimitExceeded();
    error RequestIncreasePosition__AddressListLengthMismatch();
}
