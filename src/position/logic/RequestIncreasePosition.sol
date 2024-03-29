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

import {PuppetRouter} from "./../../PuppetRouter.sol";
import {PositionStore} from "../store/PositionStore.sol";

library RequestIncreasePosition {
    event RequestIncreasePosition__Match(address trader, address subaccount, bytes32 requestKey, address[] puppetList);
    event RequestIncreasePosition__Request(
        PositionStore.RequestIncrease request,
        address subaccount,
        bytes32 requestKey,
        uint traderSizeDelta,
        uint traderCollateralDelta,
        uint puppetReduceSizeDelta,
        uint transactionCost,
        uint matchingFee
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
        uint platformFee;
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
        address[] puppetList;
    }

    struct CallParams {
        PuppetStore.Rule[] ruleList;
        uint[] activityList;
        uint[] sampledAllowanceList;
        address subaccountAddress;
        address positionStoreAddress;
        uint transactionCost;
        uint puppetReduceSizeDelta;
        uint matchingFee;
    }

    function proxyIncrease(CallConfig memory callConfig, TraderCallParams calldata traderCallParams, address trader) internal {
        address subaccount = address(callConfig.subaccountStore.getSubaccount(trader));

        if (subaccount == address(0)) {
            subaccount = address(callConfig.subaccountFactory.createSubaccount(callConfig.subaccountStore, trader));
        }

        (PuppetStore.Rule[] memory ruleList, uint[] memory activityList, uint[] memory allowanceList) =
            callConfig.puppetStore.getMatchingActivity(traderCallParams.collateralToken, trader, traderCallParams.puppetList);

        RequestIncreasePosition.CallParams memory callParams = RequestIncreasePosition.CallParams({
            ruleList: ruleList,
            activityList: activityList,
            sampledAllowanceList: allowanceList,
            subaccountAddress: subaccount,
            positionStoreAddress: address(callConfig.positionStore),
            transactionCost: gasleft() * tx.gasprice + traderCallParams.executionFee,
            puppetReduceSizeDelta: 0,
            matchingFee: 0
        });

        PositionStore.RequestIncrease memory request = PositionStore.RequestIncrease({
            trader: trader,
            puppetCollateralDeltaList: new uint[](traderCallParams.puppetList.length),
            collateralDelta: 0,
            sizeDelta: 0
        });

        PositionStore.MirrorPosition memory mirrorPosition = callConfig.positionStore.getMirrorPosition(
            GmxPositionUtils.getPositionKey(subaccount, traderCallParams.market, traderCallParams.collateralToken, traderCallParams.isLong)
        );

        if (mirrorPosition.size == 0) {
            open(callConfig, callParams, request, traderCallParams);
        } else {
            adjust(callConfig, mirrorPosition, callParams, request, traderCallParams);
        }
    }

    function increase(CallConfig memory callConfig, TraderCallParams calldata traderCallParams, address trader) internal {
        address subaccount = address(callConfig.subaccountStore.getSubaccount(trader));

        if (subaccount == address(0)) {
            subaccount = address(callConfig.subaccountFactory.createSubaccount(callConfig.subaccountStore, trader));
        }

        callConfig.router.transfer(traderCallParams.collateralToken, trader, callConfig.gmxOrderVault, traderCallParams.collateralDelta);

        (PuppetStore.Rule[] memory ruleList, uint[] memory activityList, uint[] memory allowanceList) =
            callConfig.puppetStore.getMatchingActivity(traderCallParams.collateralToken, trader, traderCallParams.puppetList);

        RequestIncreasePosition.CallParams memory callParams = RequestIncreasePosition.CallParams({
            ruleList: ruleList,
            activityList: activityList,
            sampledAllowanceList: allowanceList,
            subaccountAddress: subaccount,
            positionStoreAddress: address(callConfig.positionStore),
            transactionCost: gasleft() * tx.gasprice + traderCallParams.executionFee,
            puppetReduceSizeDelta: 0,
            matchingFee: 0
        });

        PositionStore.RequestIncrease memory request = PositionStore.RequestIncrease({
            trader: trader,
            puppetCollateralDeltaList: new uint[](traderCallParams.puppetList.length),
            collateralDelta: traderCallParams.collateralDelta,
            sizeDelta: traderCallParams.sizeDelta
        });

        PositionStore.MirrorPosition memory mirrorPosition = callConfig.positionStore.getMirrorPosition(
            GmxPositionUtils.getPositionKey(subaccount, traderCallParams.market, traderCallParams.collateralToken, traderCallParams.isLong)
        );

        if (mirrorPosition.size == 0) {
            open(callConfig, callParams, request, traderCallParams);
        } else {
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

            if (
                rule.expiry < block.timestamp // filter out frequent deposit activity. defined during rule setup
                    || callParams.activityList[i] + rule.throttleActivity > block.timestamp // expired rule. acounted every increase deposit
                    || callParams.sampledAllowanceList[i] < callConfig.minimumMatchAmount // not enough allowance
            ) continue;

            uint amountIn = sendTokenOptimistically(
                callConfig,
                traderCallParams.collateralToken,
                traderCallParams.puppetList[i],
                callParams.positionStoreAddress,
                Math.min( // the lowest of either the allowance or the trader's deposit
                    Precision.applyBasisPoints(callParams.sampledAllowanceList[i], rule.allowanceRate),
                    traderCallParams.collateralDelta // trader own deposit
                )
            );

            if (amountIn == 0) {
                callParams.sampledAllowanceList[i] = 0;
                continue;
            }

            callParams.sampledAllowanceList[i] -= amountIn;

            request.puppetCollateralDeltaList[i] = amountIn;
            request.collateralDelta += amountIn;
            request.sizeDelta +=
                Precision.applyBasisPoints(amountIn, Precision.toBasisPoints(traderCallParams.sizeDelta, traderCallParams.collateralDelta));

            callParams.activityList[i] = block.timestamp;
        }

        callConfig.puppetRouter.setMatchingActivity(
            traderCallParams.collateralToken, request.trader, traderCallParams.puppetList, callParams.activityList, callParams.sampledAllowanceList
        );

        requestKey = _createOrder(callConfig, callParams, request, traderCallParams);
        callConfig.positionStore.setRequestIncrease(requestKey, request);

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
            // did not match initial deposit
            if (mirrorPosition.puppetDepositList[i] == 0) continue;

            PuppetStore.Rule memory rule = callParams.ruleList[i];

            uint collateralDelta = mirrorPosition.puppetDepositList[i] * traderCallParams.collateralDelta / mirrorPosition.collateral;

            uint amountIn = rule.expiry < block.timestamp // filter out frequent deposit activity. defined during rule setup
                || callParams.activityList[i] + rule.throttleActivity > block.timestamp // expired rule. acounted every increase deposit
                || callParams.sampledAllowanceList[i] < collateralDelta // not enough allowance
                ? 0
                : sendTokenOptimistically(
                    callConfig, //
                    traderCallParams.collateralToken,
                    mirrorPosition.puppetList[i],
                    callParams.positionStoreAddress,
                    collateralDelta
                );

            if (amountIn > 0) {
                callParams.sampledAllowanceList[i] -= amountIn;
                request.puppetCollateralDeltaList[i] += amountIn;
                request.collateralDelta += amountIn;
                request.sizeDelta +=
                    Precision.applyBasisPoints(amountIn, Precision.toBasisPoints(traderCallParams.sizeDelta, traderCallParams.collateralDelta));

                callParams.activityList[i] = block.timestamp;
            } else {
                // not enough allowance, prevent further matching
                callParams.sampledAllowanceList[i] = 0;

                uint mpLeverage = Precision.toBasisPoints(mirrorPosition.size, mirrorPosition.collateral);
                uint mpTargetLeverage = Precision.toBasisPoints(
                    mirrorPosition.size + traderCallParams.sizeDelta, //
                    mirrorPosition.collateral + traderCallParams.collateralDelta
                );

                if (mpTargetLeverage > mpLeverage) {
                    uint deltaLeverage = mpTargetLeverage - mpLeverage;

                    request.sizeDelta += mirrorPosition.size * deltaLeverage / mpTargetLeverage;
                } else {
                    uint deltaLeverage = mpLeverage - mpTargetLeverage;

                    callParams.puppetReduceSizeDelta += mirrorPosition.size * deltaLeverage / mpLeverage;
                }
            }
        }

        callConfig.puppetRouter.setMatchingActivity(
            traderCallParams.collateralToken, request.trader, traderCallParams.puppetList, callParams.activityList, callParams.sampledAllowanceList
        );

        // if the puppet size delta is greater than the overall required size incer, increase the puppet size delta
        if (request.sizeDelta > callParams.puppetReduceSizeDelta) {
            requestKey = _createOrder(callConfig, callParams, request, traderCallParams);
        } else {
            request.sizeDelta = 0;
            bytes32 reduceKey = _reducePuppetSizeDelta(callConfig, callParams, traderCallParams);
            requestKey = _createOrder(callConfig, callParams, request, traderCallParams);
            callConfig.positionStore.setRequestIncrease(reduceKey, request);

            emit RequestIncreasePosition__RequestReducePuppetSize(
                request.trader, callParams.subaccountAddress, requestKey, reduceKey, callParams.puppetReduceSizeDelta
            );
        }

        callConfig.positionStore.setRequestIncrease(requestKey, request);

        emit RequestIncreasePosition__Request(
            request,
            callParams.subaccountAddress,
            requestKey,
            traderCallParams.sizeDelta,
            traderCallParams.collateralDelta,
            callParams.puppetReduceSizeDelta,
            callParams.transactionCost,
            callParams.matchingFee
        );
    }

    function _createOrder(
        CallConfig memory callConfig, //
        CallParams memory callParams,
        PositionStore.RequestIncrease memory request,
        TraderCallParams calldata traderCallParams
    ) internal returns (bytes32 requestKey) {
        callParams.matchingFee = PositionUtils.getPlatformMatchingFee(callConfig.platformFee, request.sizeDelta);

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

        // native ETH identified by depositing more than the execution fee
        if (address(traderCallParams.collateralToken) == address(callConfig.wnt) && traderCallParams.executionFee > msg.value) {
            TransferUtils.depositAndSendWnt(
                callConfig.wnt,
                callParams.positionStoreAddress,
                callConfig.tokenTransferGasLimit,
                callConfig.gmxOrderVault,
                traderCallParams.executionFee + request.collateralDelta
            );
        } else {
            TransferUtils.depositAndSendWnt(
                callConfig.wnt,
                callParams.positionStoreAddress,
                callConfig.tokenTransferGasLimit,
                callConfig.gmxOrderVault,
                traderCallParams.executionFee
            );
        }

        (bool orderSuccess, bytes memory orderReturnData) = Subaccount(callParams.subaccountAddress).execute(
            address(callConfig.gmxExchangeRouter), abi.encodeWithSelector(callConfig.gmxExchangeRouter.createOrder.selector, orderParams)
        );

        if (!orderSuccess) ErrorUtils.revertWithParsedMessage(orderReturnData);

        requestKey = abi.decode(orderReturnData, (bytes32));
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
                sizeDeltaUsd: callParams.puppetReduceSizeDelta,
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

        (bool orderSuccess, bytes memory orderReturnData) = Subaccount(callParams.subaccountAddress).execute(
            address(callConfig.gmxExchangeRouter), abi.encodeWithSelector(callConfig.gmxExchangeRouter.createOrder.selector, params)
        );
        if (!orderSuccess) ErrorUtils.revertWithParsedMessage(orderReturnData);

        requestKey = abi.decode(orderReturnData, (bytes32));
    }

    // non reverting token transfer, return amount transferred
    function sendTokenOptimistically(CallConfig memory callConfig, IERC20 token, address from, address to, uint amount) internal returns (uint) {
        (bool success, bytes memory returndata) = callConfig.router.rawTrasnfer{gas: callConfig.tokenTransferGasLimit}(token, from, to, amount);

        if (success && returndata.length == 0 && abi.decode(returndata, (bool))) return amount;

        return 0;
    }

    error RequestIncreasePosition__PuppetListLimitExceeded();
    error RequestIncreasePosition__AddressListLengthMismatch();
}
