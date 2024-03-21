// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {IGmxExchangeRouter} from "./../interface/IGmxExchangeRouter.sol";

import {GmxPositionUtils} from "../util/GmxPositionUtils.sol";
import {Subaccount} from "../util/Subaccount.sol";
import {ErrorUtils} from "./../../utils/ErrorUtils.sol";
import {Calc} from "./../../utils/Calc.sol";

import {SubaccountStore} from "./../store/SubaccountStore.sol";
import {PositionStore} from "../store/PositionStore.sol";
import {SubaccountStore} from "../store/SubaccountStore.sol";
import {GmxOrder} from "./GmxOrder.sol";

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
        IGmxExchangeRouter gmxExchangeRouter;
        PositionStore positionStore;
        SubaccountStore subaccountStore;
        address gmxOrderVault;
        address feeReceiver;
        bytes32 referralCode;
        uint callbackGasLimit;
    }

    struct CallParams {
        PositionStore.RequestDecrease request;
        Subaccount subaccount;
        uint totalCollateralDelta;
        uint totalSizeDelta;
    }

    function decrease(RequestDecreasePosition.CallConfig calldata callConfig, GmxOrder.CallParams calldata traderCallparams, address from) internal {
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

    function _decrease(CallConfig calldata callConfig, GmxOrder.CallParams calldata traderCallparams, CallParams memory callParams)
        internal
        returns (bytes32 requestKey)
    {
        GmxPositionUtils.CreateOrderParams memory orderParams = GmxPositionUtils.CreateOrderParams({
            addresses: GmxPositionUtils.CreateOrderParamsAddresses({
                receiver: address(callConfig.positionStore),
                callbackContract: msg.sender,
                uiFeeReceiver: callConfig.feeReceiver,
                market: traderCallparams.market,
                initialCollateralToken: traderCallparams.collateralToken,
                swapPath: new address[](0) // swapPath
            }),
            numbers: GmxPositionUtils.CreateOrderParamsNumbers({
                initialCollateralDeltaAmount: callParams.totalCollateralDelta,
                sizeDeltaUsd: callParams.totalSizeDelta,
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

        bool orderSuccess;
        bytes memory orderReturnData;

        uint totalValue = traderCallparams.executionFee + traderCallparams.collateralDelta;

        bytes[] memory callList = new bytes[](2);
        callList[0] = abi.encodeWithSelector(callConfig.gmxExchangeRouter.sendWnt.selector, callConfig.gmxOrderVault, totalValue);
        callList[1] = abi.encodeWithSelector(callConfig.gmxExchangeRouter.createOrder.selector, orderParams);

        (orderSuccess, orderReturnData) = callParams.subaccount.execute{value: msg.value}(
            address(callConfig.gmxExchangeRouter), abi.encodeWithSelector(callConfig.gmxExchangeRouter.multicall.selector, callList)
        );

        if (!orderSuccess) ErrorUtils.revertWithParsedMessage(orderReturnData);

        requestKey = abi.decode(orderReturnData, (bytes32));
    }

    error RequestDecreasePosition__SubaccountNotFound(address from);
}
