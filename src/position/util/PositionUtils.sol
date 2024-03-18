// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {PuppetStore} from "./../store/PuppetStore.sol";
import {PositionStore} from "./../store/PositionStore.sol";

import {IGmxDatastore} from "../interface/IGmxDatastore.sol";

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
        return orderType == OrderType.MarketDecrease || orderType == OrderType.Liquidation;
    }

    function isLiquidationOrder(OrderType orderType) internal pure returns (bool) {
        return orderType == OrderType.Liquidation;
    }

    function getPositionKey(address account, address market, address collateralToken, bool isLong) internal pure returns (bytes32) {
        return keccak256(abi.encode(account, market, collateralToken, isLong));
    }

    function getCurrentNonce(IGmxDatastore dataStore) internal view returns (uint) {
        return dataStore.getUint(keccak256(abi.encode("NONCE")));
    }

    function getNextRequestKey(IGmxDatastore dataStore) internal view returns (bytes32) {
        return keccak256(abi.encode(address(dataStore), getCurrentNonce(dataStore) + 1));
    }

    struct CallbackConfig {
        PositionStore positionStore;
        PuppetStore puppetStore;
        address gmxCallbackOperator;
        address caller;
    }
}
