// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IStage, Order} from "../interface/IStage.sol";
import {IGmxExchangeRouter} from "../interface/IGmxExchangeRouter.sol";
import {IGmxReadDataStore} from "../interface/IGmxReadDataStore.sol";
import {IGmxReferralStorage} from "../interface/IGmxReferralStorage.sol";
import {IBaseOrderUtils, Order as GmxOrder} from "../interface/IGmxTypes.sol";
import {Error} from "../../utils/Error.sol";

/// @title GmxStage
/// @notice Stage handler for GMX V2 perpetual trading
/// @dev Validates createOrder calls and tracks position values
contract GmxStage is IStage {
    // ============ Constants ============

    // Action types
    bytes32 public constant ACTION_INCREASE = keccak256("INCREASE");
    bytes32 public constant ACTION_DECREASE = keccak256("DECREASE");

    // GMX function selectors
    bytes4 constant MULTICALL = IGmxExchangeRouter.multicall.selector;
    bytes4 constant CREATE_ORDER = IGmxExchangeRouter.createOrder.selector;
    bytes4 constant CANCEL_ORDER = IGmxExchangeRouter.cancelOrder.selector;
    bytes4 constant CLAIM_FUNDING = IGmxExchangeRouter.claimFundingFees.selector;
    bytes4 constant CLAIM_AFFILIATE = IGmxExchangeRouter.claimAffiliateRewards.selector;
    bytes4 constant APPROVE = IERC20.approve.selector;
    bytes4 constant SET_REFERRAL = IGmxReferralStorage.setTraderReferralCodeByUser.selector;

    // GMX DataStore keys
    bytes32 constant POSITION_COLLATERAL_AMOUNT = keccak256(abi.encode("POSITION_COLLATERAL_AMOUNT"));

    // ============ Immutables ============

    IGmxReadDataStore public immutable dataStore;
    address public immutable exchangeRouter;
    address public immutable router;
    address public immutable referralStorage;

    // ============ Constructor ============

    constructor(address _dataStore, address _exchangeRouter, address _router, address _referralStorage) {
        dataStore = IGmxReadDataStore(_dataStore);
        exchangeRouter = _exchangeRouter;
        router = _router;
        referralStorage = _referralStorage;
    }

    // ============ IStage Implementation ============

    /// @notice Validate order before execution
    /// @param subaccount The subaccount executing
    /// @param token The collateral token (passed from Hook)
    /// @param order The order containing positionKey, action, callOrder
    /// @return hookData Empty for GMX (settlement via callback)
    function processOrder(address subaccount, IERC20 token, Order calldata order)
        external
        view
        override
        returns (bytes memory)
    {
        (address target, bytes memory callData) = abi.decode(order.callOrder, (address, bytes));
        _validateCall(subaccount, token, target, callData, order.action, order.positionKey);
        return "";
    }

    /// @notice Validate order after execution
    /// @param subaccount The subaccount that executed
    /// @param order The order that was executed
    /// @param preBalance Token balance before execution
    /// @param postBalance Token balance after execution
    function processPostOrder(
        address subaccount,
        IERC20,
        Order calldata order,
        uint preBalance,
        uint postBalance,
        bytes calldata
    ) external pure override {
        // Validate balance change matches action
        if (order.action == ACTION_INCREASE) {
            // Increase: balance should decrease (sent to venue)
            if (postBalance > preBalance) revert Error.GmxStage__InvalidBalanceChange();
        } else if (order.action == ACTION_DECREASE) {
            // Decrease: balance should increase (received from venue)
            if (postBalance < preBalance) revert Error.GmxStage__InvalidBalanceChange();
        }
    }

    /// @notice Settlement after GMX execution (no-op for GMX)
    /// @dev GMX positions are async - actual settlement happens via keepers
    function settle(address, Order calldata, bytes calldata) external override {}

    /// @notice Get current collateral value of a position
    /// @param positionKey The GMX position key
    /// @return value Collateral amount in token units
    function getValue(bytes32 positionKey) external view override returns (uint) {
        // Get collateral amount from GMX DataStore
        bytes32 key = keccak256(abi.encode(POSITION_COLLATERAL_AMOUNT, positionKey));
        return dataStore.getUint(key);
    }

    // ============ Internal Validation ============

    function _validateCall(address subaccount, IERC20 token, address target, bytes memory callData, bytes32 action, bytes32 expectedPositionKey)
        internal
        view
    {
        if (callData.length < 4) revert Error.GmxStage__InvalidCallData();
        bytes4 selector = bytes4(callData);

        // Token approve - validate spender
        if (selector == APPROVE) {
            (address spender,) = abi.decode(_slice(callData, 4), (address, uint));
            if (spender != router) revert Error.GmxStage__InvalidReceiver();
            return;
        }

        // Referral storage - allow setTraderReferralCodeByUser
        if (target == referralStorage) {
            if (selector != SET_REFERRAL) revert Error.GmxStage__InvalidCallData();
            return;
        }

        // Must be exchange router from here
        if (target != exchangeRouter) revert Error.GmxStage__InvalidCallData();

        // Multicall - extract and validate inner createOrder
        if (selector == MULTICALL) {
            bytes[] memory calls = abi.decode(_slice(callData, 4), (bytes[]));
            _validateMulticall(subaccount, token, calls, action, expectedPositionKey);
            return;
        }

        // Direct createOrder
        if (selector == CREATE_ORDER) {
            IBaseOrderUtils.CreateOrderParams memory params =
                abi.decode(_slice(callData, 4), (IBaseOrderUtils.CreateOrderParams));
            _validateCreateOrder(subaccount, token, params, action, expectedPositionKey);
            return;
        }

        // Cancel order - always allowed (returns funds to subaccount)
        if (selector == CANCEL_ORDER) {
            return;
        }

        // Claim operations - validate receiver
        if (selector == CLAIM_FUNDING || selector == CLAIM_AFFILIATE) {
            _validateClaimReceiver(subaccount, callData);
            return;
        }

        revert Error.GmxStage__InvalidCallData();
    }

    function _validateMulticall(address subaccount, IERC20 token, bytes[] memory calls, bytes32 action, bytes32 expectedPositionKey)
        internal
        pure
    {
        for (uint i = 0; i < calls.length; i++) {
            bytes memory call = calls[i];
            if (call.length < 4) continue;

            bytes4 selector = bytes4(call);

            if (selector == CREATE_ORDER) {
                IBaseOrderUtils.CreateOrderParams memory params =
                    abi.decode(_slice(call, 4), (IBaseOrderUtils.CreateOrderParams));
                _validateCreateOrder(subaccount, token, params, action, expectedPositionKey);
            }
            // sendWnt, sendTokens are allowed within multicall
        }
    }

    function _validateCreateOrder(
        address subaccount,
        IERC20 token,
        IBaseOrderUtils.CreateOrderParams memory params,
        bytes32 action,
        bytes32 expectedPositionKey
    ) internal pure {
        // Validate receiver
        if (params.addresses.receiver != subaccount) revert Error.GmxStage__InvalidReceiver();
        if (params.addresses.cancellationReceiver != address(0)) {
            if (params.addresses.cancellationReceiver != subaccount) revert Error.GmxStage__InvalidReceiver();
        }

        // Validate token matches
        if (params.addresses.initialCollateralToken != address(token)) revert Error.GmxStage__InvalidCallData();

        // Validate order type matches action
        GmxOrder.OrderType orderType = params.orderType;

        if (action == ACTION_INCREASE) {
            // Increase: Only increase orders
            if (
                orderType != GmxOrder.OrderType.MarketIncrease && orderType != GmxOrder.OrderType.LimitIncrease
                    && orderType != GmxOrder.OrderType.StopIncrease
            ) {
                revert Error.GmxStage__InvalidOrderType();
            }
        } else if (action == ACTION_DECREASE) {
            // Decrease: Only decrease orders
            if (
                orderType != GmxOrder.OrderType.MarketDecrease && orderType != GmxOrder.OrderType.LimitDecrease
                    && orderType != GmxOrder.OrderType.StopLossDecrease
            ) {
                revert Error.GmxStage__InvalidOrderType();
            }
        } else {
            revert Error.GmxStage__InvalidAction();
        }

        // No swaps allowed
        if (params.addresses.swapPath.length > 0) revert Error.GmxStage__InvalidOrderType();

        // Verify position key matches
        bytes32 computedKey = keccak256(
            abi.encode(
                subaccount, params.addresses.market, params.addresses.initialCollateralToken, params.isLong
            )
        );
        if (computedKey != expectedPositionKey) revert Error.GmxStage__InvalidCallData();
    }

    function _validateClaimReceiver(address subaccount, bytes memory callData) internal pure {
        // Last parameter is the receiver address
        // claimFundingFees(address[],address[],address)
        // claimAffiliateRewards(address[],address[],address)
        (, , address receiver) = abi.decode(_slice(callData, 4), (address[], address[], address));
        if (receiver != subaccount) revert Error.GmxStage__InvalidReceiver();
    }

    function _slice(bytes memory data, uint start) internal pure returns (bytes memory) {
        bytes memory result = new bytes(data.length - start);
        for (uint i = 0; i < result.length; i++) {
            result[i] = data[start + i];
        }
        return result;
    }
}
