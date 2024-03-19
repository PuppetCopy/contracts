// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {IGmxExchangeRouter} from "../interface/IGmxExchangeRouter.sol";
import {IGmxDatastore} from "../interface/IGmxDatastore.sol";

import {Router} from "src/utils/Router.sol";

import {ErrorUtils} from "./../../utils/ErrorUtils.sol";
import {GmxPositionUtils} from "../util/GmxPositionUtils.sol";
import {Subaccount} from "../util/Subaccount.sol";

import {PuppetStore} from "../store/PuppetStore.sol";
import {PositionStore} from "../store/PositionStore.sol";
import {SubaccountStore} from "./../store/SubaccountStore.sol";

import {GmxOrder} from "./GmxOrder.sol";

library RequestDecreasePosition {
    event RequestDecreasePosition__RequestIncreasePosition(
        address trader, address subaccount, bytes32 requestKey, uint[] puppetCollateralDeltaList, uint sizeDelta, uint collateralDelta
    );

    struct CallConfig {
        Router router;
        SubaccountStore subaccountStore;
        PositionStore positionStore;
        PuppetStore puppetStore;
        IGmxExchangeRouter gmxExchangeRouter;
        IGmxDatastore gmxDatastore;
        address gmxRouter;
        address feeReceiver;
        address trader;
        bytes32 referralCode;
        uint limitPuppetList;
        uint callbackGasLimit;
        uint minMatchTokenAmount;
    }

    function request(CallConfig calldata callConfig, GmxOrder.CallParams calldata callParams) internal {
        Subaccount subaccount = callConfig.subaccountStore.getSubaccount(callConfig.trader);
        address subaccountAddress = address(subaccount);

        bytes32 positionKey = GmxPositionUtils.getPositionKey(subaccountAddress, callParams.market, callParams.collateralToken, callParams.isLong);

        PositionStore.MirrorPosition memory matchMp = callConfig.positionStore.getMirrorPosition(positionKey);

        if (matchMp.size == 0) revert RequestDecreasePosition__PositionNotFound();

        if (callConfig.positionStore.getPendingRequestIncreaseAdjustmentMap(positionKey).requestKey != 0) {
            revert RequestDecreasePosition__PendingRequestExists();
        }

        uint collateralDelta = callParams.collateralDelta;
        uint sizeDelta = callParams.sizeDelta;
        uint[] memory puppetCollateralDeltaList = new uint[](callParams.puppetList.length);

        uint puppetListLength = matchMp.puppetList.length;

        for (uint i = 0; i < puppetListLength; i++) {
            puppetCollateralDeltaList[i] = callParams.collateralDelta * matchMp.puppetDepositList[i] / matchMp.collateral;
            collateralDelta -= matchMp.puppetDepositList[i] * callParams.collateralDelta / matchMp.size;
            sizeDelta -= matchMp.puppetDepositList[i] * callParams.sizeDelta / matchMp.size;
        }

        GmxPositionUtils.CreateOrderParams memory params = GmxPositionUtils.CreateOrderParams({
            addresses: GmxPositionUtils.CreateOrderParamsAddresses({
                receiver: address(callConfig.positionStore),
                callbackContract: msg.sender,
                uiFeeReceiver: callConfig.feeReceiver,
                market: callParams.market,
                initialCollateralToken: callParams.collateralToken,
                swapPath: new address[](0) // swapPath
            }),
            numbers: GmxPositionUtils.CreateOrderParamsNumbers({
                initialCollateralDeltaAmount: collateralDelta,
                sizeDeltaUsd: sizeDelta,
                triggerPrice: callParams.triggerPrice,
                acceptablePrice: callParams.acceptablePrice,
                executionFee: callParams.executionFee,
                callbackGasLimit: callConfig.callbackGasLimit,
                minOutputAmount: 0
            }),
            orderType: GmxPositionUtils.OrderType.MarketIncrease,
            decreasePositionSwapType: GmxPositionUtils.DecreasePositionSwapType.NoSwap,
            isLong: callParams.isLong,
            shouldUnwrapNativeToken: false,
            referralCode: callConfig.referralCode
        });

        (bool orderSuccess, bytes memory orderReturnData) = subaccount.execute(
            address(callConfig.gmxExchangeRouter), abi.encodeWithSelector(callConfig.gmxExchangeRouter.createOrder.selector, params)
        );
        if (!orderSuccess) ErrorUtils.revertWithParsedMessage(orderReturnData);

        bytes32 requestKey = abi.decode(orderReturnData, (bytes32));

        emit RequestDecreasePosition__RequestIncreasePosition(
            callConfig.trader, subaccountAddress, requestKey, puppetCollateralDeltaList, sizeDelta, collateralDelta
        );
    }

    error RequestDecreasePosition__PendingRequestExists();
    error RequestDecreasePosition__PositionNotFound();
}
