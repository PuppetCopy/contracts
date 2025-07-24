// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IGmxReadDataStore} from "../interface/IGmxReadDataStore.sol";

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
        return orderType == OrderType.MarketIncrease || orderType == OrderType.LimitIncrease
            || orderType == OrderType.StopIncrease;
    }

    function isDecreaseOrder(
        OrderType orderType
    ) internal pure returns (bool) {
        return orderType == OrderType.MarketDecrease || orderType == OrderType.LimitDecrease
            || orderType == OrderType.StopLossDecrease;
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

    /**
     * @notice Gets the storage key for position size in USD
     * @param positionKey The position key (hash of account, market, collateralToken, isLong)
     * @return The storage key for size in USD
     */
    function getPositionSizeKey(bytes32 positionKey) internal pure returns (bytes32) {
        return keccak256(abi.encode(positionKey, SIZE_IN_USD_KEY));
    }

    /**
     * @notice Gets the storage key for position collateral amount
     * @param positionKey The position key (hash of account, market, collateralToken, isLong)
     * @return The storage key for collateral amount
     */
    function getPositionCollateralKey(bytes32 positionKey) internal pure returns (bytes32) {
        return keccak256(abi.encode(positionKey, COLLATERAL_AMOUNT_KEY));
    }

    /**
     * @notice Reads the position size in USD from GMX DataStore
     * @param dataStore The GMX DataStore contract
     * @param positionKey The position key
     * @return The position size in USD (0 if position doesn't exist)
     */
    function getPositionSizeInUsd(
        IGmxReadDataStore dataStore,
        bytes32 positionKey
    ) internal view returns (uint) {
        bytes32 sizeKey = getPositionSizeKey(positionKey);
        return dataStore.getUint(sizeKey);
    }

    /**
     * @notice Reads the position collateral amount from GMX DataStore
     * @param dataStore The GMX DataStore contract
     * @param positionKey The position key
     * @return The position collateral amount (0 if position doesn't exist)
     */
    function getPositionCollateralAmount(
        IGmxReadDataStore dataStore,
        bytes32 positionKey
    ) internal view returns (uint) {
        bytes32 collateralKey = getPositionCollateralKey(positionKey);
        return dataStore.getUint(collateralKey);
    }
}
