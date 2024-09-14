// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IGmxDatastore} from "../interface/IGmxDataStore.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

library GmxPositionUtils {
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
        ExecutedIncrease,
        ExecutedDecrease,
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
        IERC20 initialCollateralToken;
        address[] swapPath;
    }

    struct Numbers {
        OrderType orderType;
        DecreasePositionSwapType decreasePositionSwapType;
        uint initialCollateralDeltaAmount;
        uint sizeDeltaUsd;
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
        IERC20 initialCollateralToken;
        address[] swapPath;
    }

    struct CreateOrderParamsNumbers {
        uint initialCollateralDeltaAmount;
        uint sizeDeltaUsd;
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

    function isLiquidateOrder(OrderType orderType) internal pure returns (bool) {
        return orderType == OrderType.Liquidation;
    }

    function getPositionKey(address trader, address market, IERC20 collateralToken, bool isLong) internal pure returns (bytes32) {
        return keccak256(abi.encode(trader, market, collateralToken, isLong));
    }

    function getCurrentNonce(IGmxDatastore dataStore) internal view returns (uint) {
        return dataStore.getUint(keccak256(abi.encode("NONCE")));
    }

    function getRequestKey(IGmxDatastore dataStore, uint nonce) internal pure returns (bytes32) {
        return keccak256(abi.encode(address(dataStore), nonce));
    }

    function getNextRequestKey(IGmxDatastore dataStore) internal view returns (bytes32) {
        return getRequestKey(dataStore, getCurrentNonce(dataStore) + 1);
    }

    function getCurrentRequestKey(IGmxDatastore dataStore) internal view returns (bytes32) {
        return getRequestKey(dataStore, getCurrentNonce(dataStore));
    }
}
