// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {IGmxExchangeRouter} from "./../interface/IGmxExchangeRouter.sol";
import {Subaccount} from "./../../shared/Subaccount.sol";

import {PositionUtils} from "./../utils/PositionUtils.sol";
import {GmxPositionUtils} from "../utils/GmxPositionUtils.sol";
import {ErrorUtils} from "./../../utils/ErrorUtils.sol";
import {IWNT} from "./../../utils/interfaces/IWNT.sol";

import {PositionStore} from "../store/PositionStore.sol";
import {SubaccountStore} from "./../../shared/store/SubaccountStore.sol";

library RequestDecreasePosition {
    event RequestDecreasePosition__Request(
        PositionStore.RequestAdjustment request, address subaccount, bytes32 requestKey, uint traderSizeDelta, uint traderCollateralDelta
    );

    struct CallConfig {
        IWNT wnt;
        IGmxExchangeRouter gmxExchangeRouter;
        PositionStore positionStore;
        SubaccountStore subaccountStore;
        address gmxOrderReciever;
        address gmxOrderVault;
        bytes32 referralCode;
        uint callbackGasLimit;
    }

    function traderDecrease(CallConfig memory callConfig, PositionUtils.TraderCallParams calldata traderCallParams) internal {
        uint startGas = gasleft();

        Subaccount subaccount = callConfig.subaccountStore.getSubaccount(traderCallParams.account);
        address subaccountAddress = address(subaccount);

        if (subaccountAddress == address(0)) revert RequestDecreasePosition__SubaccountNotFound(traderCallParams.account);

        bytes32 positionKey = GmxPositionUtils.getPositionKey(
            subaccountAddress, //
            traderCallParams.market,
            traderCallParams.collateralToken,
            traderCallParams.isLong
        );

        PositionStore.MirrorPosition memory mirrorPosition = callConfig.positionStore.getMirrorPosition(positionKey);

        PositionStore.RequestAdjustment memory request = PositionStore.RequestAdjustment({
            puppetCollateralDeltaList: new uint[](mirrorPosition.puppetList.length),
            collateralDelta: traderCallParams.collateralDelta,
            sizeDelta: traderCallParams.sizeDelta,
            transactionCost: startGas
        });

        decrease(callConfig, request, mirrorPosition, traderCallParams, subaccount, subaccountAddress);
    }

    function proxyDecrease(CallConfig memory callConfig, PositionUtils.TraderCallParams calldata traderCallParams) internal {
        uint startGas = gasleft();

        Subaccount subaccount = callConfig.subaccountStore.getSubaccount(traderCallParams.account);
        address subaccountAddress = address(subaccount);

        if (subaccountAddress == address(0)) revert RequestDecreasePosition__SubaccountNotFound(traderCallParams.account);

        bytes32 positionKey = GmxPositionUtils.getPositionKey(
            subaccountAddress, //
            traderCallParams.market,
            traderCallParams.collateralToken,
            traderCallParams.isLong
        );

        PositionStore.MirrorPosition memory mirrorPosition = callConfig.positionStore.getMirrorPosition(positionKey);

        PositionStore.RequestAdjustment memory request = PositionStore.RequestAdjustment({
            puppetCollateralDeltaList: new uint[](mirrorPosition.puppetList.length),
            collateralDelta: 0,
            sizeDelta: 0,
            transactionCost: startGas
        });

        decrease(callConfig, request, mirrorPosition, traderCallParams, subaccount, subaccountAddress);
    }

    function decrease(
        CallConfig memory callConfig,
        PositionStore.RequestAdjustment memory request,
        PositionStore.MirrorPosition memory mirrorPosition,
        PositionUtils.TraderCallParams calldata traderCallParams,
        Subaccount subaccount,
        address subaccountAddress
    ) internal {
        for (uint i = 0; i < mirrorPosition.puppetList.length; i++) {
            request.puppetCollateralDeltaList[i] -=
                request.puppetCollateralDeltaList[i] * traderCallParams.collateralDelta / mirrorPosition.collateral;
        }

        GmxPositionUtils.CreateOrderParams memory orderParams = GmxPositionUtils.CreateOrderParams({
            addresses: GmxPositionUtils.CreateOrderParamsAddresses({
                receiver: callConfig.gmxOrderReciever,
                callbackContract: callConfig.gmxOrderReciever,
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
            orderType: GmxPositionUtils.OrderType.MarketDecrease,
            decreasePositionSwapType: GmxPositionUtils.DecreasePositionSwapType.NoSwap,
            isLong: traderCallParams.isLong,
            shouldUnwrapNativeToken: false,
            referralCode: callConfig.referralCode
        });

        (bool orderSuccess, bytes memory orderReturnData) = subaccount.execute(
            address(callConfig.gmxExchangeRouter), abi.encodeWithSelector(callConfig.gmxExchangeRouter.createOrder.selector, orderParams)
        );

        if (!orderSuccess) ErrorUtils.revertWithParsedMessage(orderReturnData);

        bytes32 requestKey = abi.decode(orderReturnData, (bytes32));

        request.transactionCost = (request.transactionCost - gasleft()) * tx.gasprice + traderCallParams.executionFee;

        callConfig.positionStore.setRequestAdjustment(requestKey, request);

        emit RequestDecreasePosition__Request(request, subaccountAddress, requestKey, traderCallParams.sizeDelta, traderCallParams.collateralDelta);
    }

    error RequestDecreasePosition__SubaccountNotFound(address user);
}
