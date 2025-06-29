// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import {IGmxExchangeRouter} from "../interface/IGmxExchangeRouter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

library GmxPositionUtils {
    bytes32 public constant SIZE_IN_USD_KEY = keccak256(abi.encode("SIZE_IN_USD"));
    bytes32 public constant COLLATERAL_AMOUNT_KEY = keccak256(abi.encode("COLLATERAL_AMOUNT"));

    enum OrderType {
        MarketSwap, // 0
        LimitSwap, // 1
        MarketIncrease, // 2
        LimitIncrease, // 3
        MarketDecrease, // 4
        LimitDecrease, // 5
        StopLossDecrease, // 6
        Liquidation // 7

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

    // @dev CreateOrderParams struct used in createOrder to avoid stack
    // too deep errors
    //
    // @param addresses address values
    // @param numbers number values
    // @param orderType for order.orderType
    // @param decreasePositionSwapType for order.decreasePositionSwapType
    // @param isLong for order.isLong
    // @param shouldUnwrapNativeToken for order.shouldUnwrapNativeToken
    // @note all params except should be part of the corresponding struct hash in all relay contracts
    struct CreateOrderParams {
        CreateOrderParamsAddresses addresses;
        CreateOrderParamsNumbers numbers;
        OrderType orderType;
        DecreasePositionSwapType decreasePositionSwapType;
        bool isLong;
        bool shouldUnwrapNativeToken;
        bool autoCancel;
        bytes32 referralCode;
    }

    // @note all params except should be part of the corresponding struct hash in all relay contracts
    struct CreateOrderParamsAddresses {
        address receiver; // The AllocationAccount contract owns the position on GMX
        address cancellationReceiver; // Where funds go if order is cancelled before execution
        address callbackContract; // Contract GMX calls after execution/failure
        address uiFeeReceiver; // Optional: Address for UI referral fees
        address market; // The market identifier on GMX
        IERC20 initialCollateralToken; // The collateral token address
        address[] swapPath; // Path for potential collateral swap (not used here)
    }

    // @param sizeDeltaUsd for order.sizeDeltaUsd
    // @param triggerPrice for order.triggerPrice
    // @param acceptablePrice for order.acceptablePrice
    // @param executionFee for order.executionFee
    // @param callbackGasLimit for order.callbackGasLimit
    // @param minOutputAmount for order.minOutputAmount
    // @param validFromTime for order.validFromTime
    // @note all params except should be part of the corresponding struct hash in all relay contracts
    struct CreateOrderParamsNumbers {
        uint sizeDeltaUsd;
        uint initialCollateralDeltaAmount;
        uint triggerPrice;
        uint acceptablePrice;
        uint executionFee;
        uint callbackGasLimit;
        uint minOutputAmount;
        uint validFromTime;
    }

    function isIncreaseOrder(
        OrderType orderType
    ) internal pure returns (bool) {
        return orderType == OrderType.MarketIncrease || orderType == OrderType.LimitIncrease;
    }

    function isDecreaseOrder(
        OrderType orderType
    ) internal pure returns (bool) {
        return orderType == OrderType.MarketDecrease || orderType == OrderType.Liquidation;
    }

    function isLiquidateOrder(
        OrderType orderType
    ) internal pure returns (bool) {
        return orderType == OrderType.Liquidation;
    }

    function getPositionKey(
        address account,
        address market,
        IERC20 collateralToken,
        bool isLong
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(account, market, collateralToken, isLong));
    }
}
