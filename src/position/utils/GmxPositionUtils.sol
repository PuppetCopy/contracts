// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import {IGmxExchangeRouter} from "../interface/IGmxExchangeRouter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

library GmxPositionUtils {
    bytes32 public constant SIZE_IN_USD_KEY = keccak256(abi.encode("SIZE_IN_USD"));
    bytes32 public constant COLLATERAL_AMOUNT_KEY = keccak256(abi.encode("COLLATERAL_AMOUNT"));

    enum OrderType {
        MarketSwap,
        LimitSwap,
        MarketIncrease,
        LimitIncrease,
        MarketDecrease,
        LimitDecrease,
        StopLossDecrease,
        Liquidation,
        StopIncrease
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
        address cancellationReceiver;
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
        uint updatedAtTime;
        uint validFromTime;
    }

    struct Flags {
        bool isLong;
        bool shouldUnwrapNativeToken;
        bool isFrozen;
        bool autoCancel;
    }

    struct AddressKeyValue {
        string key;
        address value;
    }

    struct AddressArrayKeyValue {
        string key;
        address[] value;
    }

    struct UintKeyValue {
        string key;
        uint value;
    }

    struct UintArrayKeyValue {
        string key;
        uint[] value;
    }

    struct IntKeyValue {
        string key;
        int value;
    }

    struct IntArrayKeyValue {
        string key;
        int[] value;
    }

    struct BoolKeyValue {
        string key;
        bool value;
    }

    struct BoolArrayKeyValue {
        string key;
        bool[] value;
    }

    struct Bytes32KeyValue {
        string key;
        bytes32 value;
    }

    struct Bytes32ArrayKeyValue {
        string key;
        bytes32[] value;
    }

    struct BytesKeyValue {
        string key;
        bytes value;
    }

    struct BytesArrayKeyValue {
        string key;
        bytes[] value;
    }

    struct StringKeyValue {
        string key;
        string value;
    }

    struct StringArrayKeyValue {
        string key;
        string[] value;
    }

    struct AddressItems {
        AddressKeyValue[] items;
        AddressArrayKeyValue[] arrayItems;
    }

    struct UintItems {
        UintKeyValue[] items;
        UintArrayKeyValue[] arrayItems;
    }

    struct IntItems {
        IntKeyValue[] items;
        IntArrayKeyValue[] arrayItems;
    }

    struct BoolItems {
        BoolKeyValue[] items;
        BoolArrayKeyValue[] arrayItems;
    }

    struct Bytes32Items {
        Bytes32KeyValue[] items;
        Bytes32ArrayKeyValue[] arrayItems;
    }

    struct BytesItems {
        BytesKeyValue[] items;
        BytesArrayKeyValue[] arrayItems;
    }

    struct StringItems {
        StringKeyValue[] items;
        StringArrayKeyValue[] arrayItems;
    }

    struct EventLogData {
        AddressItems addressItems;
        UintItems uintItems;
        IntItems intItems;
        BoolItems boolItems;
        Bytes32Items bytes32Items;
        BytesItems bytesItems;
        StringItems stringItems;
    }

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
