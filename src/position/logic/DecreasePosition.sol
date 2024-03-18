// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IGmxExchangeRouter} from "../interface/IGmxExchangeRouter.sol";
import {IGmxDatastore} from "../interface/IGmxDatastore.sol";
import {IGmxEventUtils} from "./../interface/IGmxEventUtils.sol";

import {Router} from "src/utils/Router.sol";
import {Calc} from "src/utils/Calc.sol";

import {ErrorUtils} from "./../../utils/ErrorUtils.sol";
import {PositionUtils} from "../util/PositionUtils.sol";
import {Subaccount} from "../util/Subaccount.sol";

import {PuppetStore} from "../store/PuppetStore.sol";
import {PositionStore} from "../store/PositionStore.sol";
import {SubaccountStore} from "./../store/SubaccountStore.sol";

library DecreasePosition {
    event DecreasePosition__RequestIncreasePosition(
        address trader, address subaccount, bytes32 requestKey, uint[] puppetCollateralDeltaList, uint sizeDelta, uint collateralDelta
    );

    struct CallParams {
        address market;
        uint executionFee;
        uint sizeDelta;
        uint collateralDelta;
        uint acceptablePrice;
        uint triggerPrice;
        bool isLong;
        address[] puppetList;
    }

    struct CallConfig {
        Router router;
        SubaccountStore subaccountStore;
        PositionStore positionStore;
        PuppetStore puppetStore;
        IGmxExchangeRouter gmxExchangeRouter;
        IGmxDatastore gmxDatastore;
        address gmxRouter;
        IERC20 depositCollateralToken;
        address gmxCallbackOperator;
        address feeReceiver;
        address trader;
        bytes32 referralCode;
        uint limitPuppetList;
        uint adjustmentFeeFactor;
        uint callbackGasLimit;
        uint minMatchTokenAmount;
    }

    function requestDecreasePosition(CallConfig calldata callConfig, CallParams calldata callParams) internal {
        Subaccount subaccount = callConfig.subaccountStore.getSubaccount(callConfig.trader);
        address subaccountAddress = address(subaccount);

        bytes32 positionKey =
            PositionUtils.getPositionKey(subaccountAddress, callParams.market, address(callConfig.depositCollateralToken), callParams.isLong);

        PositionStore.MirrorPosition memory matchMp = callConfig.positionStore.getMirrorPosition(positionKey);

        if (matchMp.size == 0) {
            revert DecreasePosition__PositionNotFound();
        }

        if (callConfig.positionStore.getPendingRequestIncreaseAdjustmentMap(positionKey).requestKey != 0) {
            revert DecreasePosition__PendingRequestExists();
        }

        if (subaccountAddress != callConfig.trader) revert DecreasePosition__InvalidSubaccountTrader();

        uint sizeDelta = callParams.sizeDelta;
        uint collateralDelta = callParams.collateralDelta;
        uint[] memory puppetCollateralDeltaList = new uint[](callParams.puppetList.length);

        uint puppetListLength = matchMp.puppetList.length;

        for (uint i = 0; i < puppetListLength; i++) {
            puppetCollateralDeltaList[i] = callParams.collateralDelta * matchMp.puppetDepositList[i] / matchMp.collateral;
            collateralDelta -= puppetCollateralDeltaList[i];
            // sizeDelta -= int(matchMp.puppetDepositList[i] * callParams.sizeDelta / matchMp.size);
        }

        PositionUtils.CreateOrderParams memory params = PositionUtils.CreateOrderParams({
            addresses: PositionUtils.CreateOrderParamsAddresses({
                receiver: address(callConfig.positionStore),
                callbackContract: callConfig.gmxCallbackOperator,
                uiFeeReceiver: callConfig.feeReceiver,
                market: callParams.market,
                initialCollateralToken: address(callConfig.depositCollateralToken),
                swapPath: new address[](0) // swapPath
            }),
            numbers: PositionUtils.CreateOrderParamsNumbers({
                sizeDeltaUsd: sizeDelta,
                initialCollateralDeltaAmount: collateralDelta,
                triggerPrice: callParams.triggerPrice,
                acceptablePrice: callParams.acceptablePrice,
                executionFee: callParams.executionFee,
                callbackGasLimit: callConfig.callbackGasLimit,
                minOutputAmount: 0
            }),
            orderType: PositionUtils.OrderType.MarketIncrease,
            decreasePositionSwapType: PositionUtils.DecreasePositionSwapType.NoSwap,
            isLong: callParams.isLong,
            shouldUnwrapNativeToken: false,
            referralCode: callConfig.referralCode
        });

        (bool orderSuccess, bytes memory orderReturnData) = subaccount.execute(
            address(callConfig.gmxExchangeRouter), abi.encodeWithSelector(callConfig.gmxExchangeRouter.createOrder.selector, params)
        );
        if (!orderSuccess) ErrorUtils.revertWithParsedMessage(orderReturnData);

        bytes32 requestKey = abi.decode(orderReturnData, (bytes32));

        emit DecreasePosition__RequestIncreasePosition(
            callConfig.trader, subaccountAddress, requestKey, puppetCollateralDeltaList, sizeDelta, collateralDelta
        );
    }

    function executeDecreasePosition(
        PositionUtils.CallbackConfig calldata callConfig,
        bytes32 key,
        PositionUtils.Props calldata order,
        bytes calldata eventData
    ) external {
        (IGmxEventUtils.EventLogData memory eventLogData) = abi.decode(eventData, (IGmxEventUtils.EventLogData));

        // Check if there is at least one uint item available
        if (eventLogData.uintItems.items.length == 0 && eventLogData.uintItems.arrayItems.length == 0) {
            revert DecreasePosition__UnexpectedEventData();
        }

        address outputToken = eventLogData.addressItems.items[0].value;
        uint outputAmount = eventLogData.uintItems.items[0].value;

        bytes32 positionKey =
            PositionUtils.getPositionKey(order.addresses.account, order.addresses.market, order.addresses.initialCollateralToken, order.flags.isLong);
        callConfig.positionStore.removePendingRequestIncreaseAdjustmentMap(positionKey);

        // request.subaccount.depositToken(callConfig.router, callConfig.depositCollateralToken, callParams.collateralDelta);
        // SafeERC20.safeTransferFrom(callConfig.depositCollateralToken, address(callConfig.puppetStore), subaccountAddress, request.collateralDelta);
    }

    function _forceApprove(IERC20 token, address spender, uint value) external {
        SafeERC20.forceApprove(token, spender, value);
    }

    error DecreasePosition__UnexpectedEventData();
    error DecreasePosition__PendingRequestExists();
    error DecreasePosition__PositionNotFound();
    error DecreasePosition__InvalidSubaccountTrader();
}
