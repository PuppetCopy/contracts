// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {IGmxExchangeRouter} from "./../interface/IGmxExchangeRouter.sol";

import {IWNT} from "./../../utils/interfaces/IWNT.sol";
import {GmxPositionUtils} from "../util/GmxPositionUtils.sol";
import {Subaccount} from "../util/Subaccount.sol";
import {ErrorUtils} from "./../../utils/ErrorUtils.sol";

import {PositionStore} from "../store/PositionStore.sol";
import {SubaccountStore} from "../store/SubaccountStore.sol";
import {GmxOrder} from "./GmxOrder.sol";

library RequestDecreasePosition {
    event RequestDecreasePosition__Request(
        address trader, address subaccount, bytes32 requestKey, uint[] puppetCollateralDeltaList, int sizeDelta, uint collateralDelta
    );

    struct CallConfig {
        IWNT wnt;
        IGmxExchangeRouter gmxExchangeRouter;
        PositionStore positionStore;
        SubaccountStore subaccountStore;
        address gmxOrderVault;
        address feeReceiver;
        bytes32 referralCode;
        uint callbackGasLimit;
    }

    function reduce(
        CallConfig calldata callConfig,
        GmxOrder.CallParams calldata callParams,
        PositionStore.RequestAdjustment memory request
    ) external {
        GmxPositionUtils.CreateOrderParams memory orderParams = GmxPositionUtils.CreateOrderParams({
            addresses: GmxPositionUtils.CreateOrderParamsAddresses({
                receiver: address(callConfig.positionStore),
                callbackContract: msg.sender,
                uiFeeReceiver: callConfig.feeReceiver,
                market: callParams.market,
                initialCollateralToken: callParams.collateralToken,
                swapPath: new address[](0) // swapPath
            }),
            numbers: GmxPositionUtils.CreateOrderParamsNumbers({
                initialCollateralDeltaAmount: request.collateralDelta,
                sizeDeltaUsd: uint(request.sizeDelta),
                triggerPrice: callParams.triggerPrice,
                acceptablePrice: callParams.acceptablePrice,
                executionFee: callParams.executionFee,
                callbackGasLimit: callConfig.callbackGasLimit,
                minOutputAmount: 0
            }),
            orderType: GmxPositionUtils.OrderType.MarketDecrease,
            decreasePositionSwapType: GmxPositionUtils.DecreasePositionSwapType.NoSwap,
            isLong: callParams.isLong,
            shouldUnwrapNativeToken: false,
            referralCode: callConfig.referralCode
        });

        bool orderSuccess;
        bytes memory orderReturnData;

        uint totalValue = callParams.executionFee + callParams.collateralDelta;

        bytes[] memory callList = new bytes[](2);
        callList[0] = abi.encodeWithSelector(callConfig.gmxExchangeRouter.sendWnt.selector, callConfig.gmxOrderVault, totalValue);
        callList[1] = abi.encodeWithSelector(callConfig.gmxExchangeRouter.createOrder.selector, orderParams);

        (orderSuccess, orderReturnData) = request.subaccount.execute{value: msg.value}(
            address(callConfig.gmxExchangeRouter), abi.encodeWithSelector(callConfig.gmxExchangeRouter.multicall.selector, callList)
        );

        if (!orderSuccess) ErrorUtils.revertWithParsedMessage(orderReturnData);

        bytes32 requestKey = abi.decode(orderReturnData, (bytes32));

        callConfig.positionStore.setPendingRequestMap(requestKey, request);
    }
}
