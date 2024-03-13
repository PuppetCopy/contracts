// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IGmxExchangeRouter} from "../interface/IGmxExchangeRouter.sol";
import {IGmxDatastore} from "../interface/IGmxDatastore.sol";
import {Router} from "../../utils/Router.sol";

import {PositionStore} from "./../store/PositionStore.sol";
import {PuppetStore} from "./../store/PuppetStore.sol";
import {SubaccountStore} from "./../store/SubaccountStore.sol";

library PositionUtils {
    enum OrderType {
        MarketSwap,
        LimitSwap,
        MarketIncrease,
        LimitIncrease,
        MarketDecrease,
        LimitDecrease,
        StopLossDecrease,
        Liquidation
    }

    enum OrderExecutionStatus {
        Executed,
        Cancelled,
        Frozen
    }

    enum DecreasePositionSwapType {
        NoSwap,
        SwapPnlTokenToCollateralToken,
        SwapCollateralTokenToPnlToken
    }

    struct CallPositionConfig {
        SubaccountStore subaccountStore;
        PositionStore positionStore;
        PuppetStore puppetStore;
        Router router;
        IGmxExchangeRouter gmxExchangeRouter;
        IGmxDatastore gmxDatastore;
        IERC20 depositCollateralToken;
        address feeReceiver;
        uint limitPuppetList;
        uint adjustmentFeeFactor;
        uint minExecutionFee;
        uint maxCallbackGasLimit;
        uint minMatchTokenAmount;
        bytes32 referralCode;
    }

    struct CallPositionAdjustment {
        address trader;
        address receiver;
        address market;
        uint executionFee;
        uint collateralDelta;
        uint sizeDelta;
        uint acceptablePrice;
        uint triggerPrice;
        bool isLong;
    }

    struct Props {
        Addresses addresses;
        Numbers numbers;
        Flags flags;
    }

    struct Addresses {
        address account;
        address receiver;
        address callbackContract;
        address uiFeeReceiver;
        address market;
        address initialCollateralToken;
        address[] swapPath;
    }

    struct Numbers {
        OrderType orderType;
        DecreasePositionSwapType decreasePositionSwapType;
        uint sizeDeltaUsd;
        uint initialCollateralDeltaAmount;
        uint triggerPrice;
        uint acceptablePrice;
        uint executionFee;
        uint callbackGasLimit;
        uint minOutputAmount;
        uint updatedAtBlock;
    }

    struct Flags {
        bool isLong;
        bool shouldUnwrapNativeToken;
        bool isFrozen;
    }

    error InvalidOrderType();

    struct CreateOrderParams {
        CreateOrderParamsAddresses addresses;
        CreateOrderParamsNumbers numbers;
        OrderType orderType;
        DecreasePositionSwapType decreasePositionSwapType;
        bool isLong;
        bool shouldUnwrapNativeToken;
        bytes32 referralCode;
    }

    struct CreateOrderParamsAddresses {
        address receiver;
        address callbackContract;
        address uiFeeReceiver;
        address market;
        address initialCollateralToken;
        address[] swapPath;
    }

    struct CreateOrderParamsNumbers {
        uint sizeDeltaUsd;
        uint initialCollateralDeltaAmount;
        uint triggerPrice;
        uint acceptablePrice;
        uint executionFee;
        uint callbackGasLimit;
        uint minOutputAmount;
    }

    function isIncreaseOrder(OrderType orderType) internal pure returns (bool) {
        return orderType == OrderType.MarketIncrease || orderType == OrderType.LimitIncrease;
    }

    function isDecreaseOrder(OrderType orderType) internal pure returns (bool) {
        return orderType == OrderType.MarketDecrease || orderType == OrderType.LimitDecrease || orderType == OrderType.StopLossDecrease
            || orderType == OrderType.Liquidation;
    }

    function isLiquidationOrder(OrderType orderType) internal pure returns (bool) {
        return orderType == OrderType.Liquidation;
    }

    function getPositionKey(address account, address market, IERC20 collateralToken, bool isLong) internal pure returns (bytes32) {
        return keccak256(abi.encode(account, market, address(collateralToken), isLong));
    }

    function getNextRequestKey(IGmxDatastore dataStore) internal returns (bytes32) {
        uint nonce = dataStore.incrementUint(keccak256(abi.encode("NONCE")), 1);

        return keccak256(abi.encode(address(dataStore), nonce));
    }
}
