// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {IGmxExchangeRouter} from "./../interface/IGmxExchangeRouter.sol";
import {IWNT} from "./../../utils/interfaces/IWNT.sol";

import {GmxPositionUtils} from "../util/GmxPositionUtils.sol";
import {Subaccount} from "../../shared/Subaccount.sol";
import {ErrorUtils} from "./../../utils/ErrorUtils.sol";
import {TransferUtils} from "./../../utils/TransferUtils.sol";

import {PositionStore} from "../store/PositionStore.sol";
import {SubaccountStore} from "../../shared/store/SubaccountStore.sol";

library RequestDecreasePosition {
    event RequestIncreasePosition__Request(
        address trader,
        address subaccount,
        bytes32 requestKey,
        uint[] puppetCollateralDeltaList,
        uint sizeDelta,
        uint totalSizeDelta,
        uint collateralDelta,
        uint totalCollateralDelta
    );

    struct CallConfig {
        IWNT wnt;
        IGmxExchangeRouter gmxExchangeRouter;
        PositionStore positionStore;
        SubaccountStore subaccountStore;
        address positionRouterAddress;
        address gmxOrderVault;
        bytes32 referralCode;
        uint callbackGasLimit;
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
    }

    struct CallParams {
        PositionStore.RequestDecrease request;
        Subaccount subaccount;
        uint totalCollateralDelta;
        uint totalSizeDelta;
    }

    function decrease(CallConfig memory callConfig, TraderCallParams calldata traderCallparams, address from) internal {
        Subaccount subaccount = callConfig.subaccountStore.getSubaccount(from);
        address subaccountAddress = address(subaccount);

        if (subaccountAddress == address(0)) revert RequestDecreasePosition__SubaccountNotFound(from);

        bytes32 positionKey =
            GmxPositionUtils.getPositionKey(subaccountAddress, traderCallparams.market, traderCallparams.collateralToken, traderCallparams.isLong);

        PositionStore.MirrorPosition memory mirrorPosition = callConfig.positionStore.getMirrorPosition(positionKey);

        PositionStore.RequestDecrease memory request = PositionStore.RequestDecrease({
            trader: from,
            puppetCollateralDeltaList: new uint[](0),
            collateralDelta: traderCallparams.collateralDelta,
            sizeDelta: traderCallparams.sizeDelta
        });

        CallParams memory callParams = CallParams({
            request: request,
            subaccount: subaccount,
            totalCollateralDelta: mirrorPosition.totalCollateral * traderCallparams.collateralDelta / mirrorPosition.collateral,
            totalSizeDelta: mirrorPosition.totalSize * traderCallparams.sizeDelta / mirrorPosition.size
        });

        for (uint i = 0; i < mirrorPosition.puppetList.length; i++) {
            request.puppetCollateralDeltaList[i] -=
                request.puppetCollateralDeltaList[i] * traderCallparams.collateralDelta / mirrorPosition.collateral;
        }

        bytes32 requestKey = _decrease(callConfig, traderCallparams, callParams);

        callConfig.positionStore.setRequestDecreaseMap(requestKey, request);

        emit RequestIncreasePosition__Request(
            from,
            subaccountAddress,
            requestKey,
            request.puppetCollateralDeltaList,
            request.sizeDelta,
            callParams.totalSizeDelta,
            request.collateralDelta,
            callParams.totalCollateralDelta
        );
    }

    function _decrease(CallConfig memory callConfig, TraderCallParams calldata traderCallParams, CallParams memory callParams)
        internal
        returns (bytes32 requestKey)
    {
        GmxPositionUtils.CreateOrderParams memory orderParams = GmxPositionUtils.CreateOrderParams({
            addresses: GmxPositionUtils.CreateOrderParamsAddresses({
                receiver: address(callConfig.positionStore),
                callbackContract: address(this),
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
            orderType: GmxPositionUtils.OrderType.MarketDecrease,
            decreasePositionSwapType: GmxPositionUtils.DecreasePositionSwapType.NoSwap,
            isLong: traderCallParams.isLong,
            shouldUnwrapNativeToken: false,
            referralCode: callConfig.referralCode
        });

        TransferUtils.depositAndSendWnt(
            callConfig.wnt,
            address(callConfig.positionStore),
            callConfig.tokenTransferGasLimit,
            callConfig.gmxOrderVault,
            traderCallParams.executionFee + traderCallParams.collateralDelta
        );

        (bool orderSuccess, bytes memory orderReturnData) = callParams.subaccount.execute(
            address(callConfig.gmxExchangeRouter), abi.encodeWithSelector(callConfig.gmxExchangeRouter.createOrder.selector, orderParams)
        );

        if (!orderSuccess) ErrorUtils.revertWithParsedMessage(orderReturnData);

        requestKey = abi.decode(orderReturnData, (bytes32));
    }

    error RequestDecreasePosition__SubaccountNotFound(address from);
}
