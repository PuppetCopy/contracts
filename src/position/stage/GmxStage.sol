// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {CallType, CALLTYPE_SINGLE} from "modulekit/accounts/common/lib/ModeLib.sol";
import {ExecutionLib} from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import {IExchangeRouter} from "gmx-synthetics/router/IExchangeRouter.sol";

import {IBaseOrderUtils} from "gmx-synthetics/order/IBaseOrderUtils.sol";
import {Order} from "gmx-synthetics/order/Order.sol";

import {IStage, Call} from "../interface/IStage.sol";
import {IGmxDataStore} from "../interface/IGmxDataStore.sol";
import {IChainlinkAggregator} from "../interface/IChainlinkAggregator.sol";
import {Error} from "../../utils/Error.sol";
import {Precision} from "../../utils/Precision.sol";

/// @title GmxStage
/// @notice Stage handler for GMX V2 perpetual trading
/// @dev Validates raw execution data and determines action from selectors
contract GmxStage is IStage {
    // ============ GMX Selectors ============
    // @dev lib/gmx-synthetics/contracts/router/BaseRouter.sol
    bytes4 public constant MULTICALL = 0xac9650d8;   // multicall(bytes[])
    bytes4 public constant SEND_WNT = 0x7d39aaf1;    // sendWnt(address,uint256)
    bytes4 public constant SEND_TOKENS = 0xe6d66ac8; // sendTokens(address,address,uint256)
    // @dev gmx-synthetics/router/IExchangeRouter.sol
    bytes4 public constant CREATE_ORDER = IExchangeRouter.createOrder.selector;
    bytes4 public constant CANCEL_ORDER = IExchangeRouter.cancelOrder.selector;
    // @dev lib/gmx-synthetics/contracts/router/ExchangeRouter.sol:349
    bytes4 public constant CLAIM_FUNDING = 0xc41b1ab3; // claimFundingFees(address[],address[],address)
    // bytes4 public constant CLAIM_AFFILIATE = IExchangeRouter.claimAffiliateRewards.selector;
    bytes4 public constant APPROVE = IERC20.approve.selector;

    // ============ GMX Keys ============
    // @dev GMX NonceUtils uses this to derive orderKey
    bytes32 public constant NONCE_KEY = keccak256(abi.encode("NONCE"));
    // @dev GMX OrderStoreUtils uses this to check order existence
    bytes32 public constant ORDER_LIST = keccak256(abi.encode("ORDER_LIST"));

    // @dev Position data keys (from GMX Keys.sol)
    bytes32 internal constant POSITION_COLLATERAL_AMOUNT = keccak256(abi.encode("POSITION_COLLATERAL_AMOUNT"));
    bytes32 internal constant POSITION_COLLATERAL_TOKEN = keccak256(abi.encode("POSITION_COLLATERAL_TOKEN"));
    bytes32 internal constant POSITION_SIZE_IN_USD = keccak256(abi.encode("POSITION_SIZE_IN_USD"));
    bytes32 internal constant POSITION_SIZE_IN_TOKENS = keccak256(abi.encode("POSITION_SIZE_IN_TOKENS"));
    bytes32 internal constant POSITION_IS_LONG = keccak256(abi.encode("POSITION_IS_LONG"));
    bytes32 internal constant POSITION_ACCOUNT = keccak256(abi.encode("POSITION_ACCOUNT"));
    bytes32 internal constant POSITION_MARKET = keccak256(abi.encode("POSITION_MARKET"));

    // @dev Market data keys
    bytes32 internal constant MARKET_INDEX_TOKEN = keccak256(abi.encode("MARKET_INDEX_TOKEN"));

    // @dev Price feed keys
    bytes32 internal constant PRICE_FEED = keccak256(abi.encode("PRICE_FEED"));
    bytes32 internal constant PRICE_FEED_MULTIPLIER = keccak256(abi.encode("PRICE_FEED_MULTIPLIER"));

    // @dev Borrowing fee keys (from PositionStoreUtils + Keys.sol)
    bytes32 internal constant BORROWING_FACTOR = keccak256(abi.encode("BORROWING_FACTOR"));
    bytes32 internal constant CUMULATIVE_BORROWING_FACTOR = keccak256(abi.encode("CUMULATIVE_BORROWING_FACTOR"));

    // ============ Action Types ============
    // @dev Used in hookData to indicate what action was performed
    uint8 public constant ACTION_NONE = 0;           // No order created (claims, etc.)
    uint8 public constant ACTION_ORDER_CREATED = 1;  // Order was created

    // ============ Immutables ============

    IGmxDataStore public immutable dataStore;
    address public immutable exchangeRouter;
    address public immutable orderVault;
    address public immutable wnt;

    // ============ Constructor ============

    constructor(address _dataStore, address _exchangeRouter, address _orderVault, address _wnt) {
        dataStore = IGmxDataStore(_dataStore);
        exchangeRouter = _exchangeRouter;
        orderVault = _orderVault;
        wnt = _wnt;
    }

    // ============ IStage Implementation ============

    /// @notice Validate execution before it runs
    /// @dev Token is extracted from execution data, not passed as parameter
    function validate(
        address,
        address subaccount,
        uint,
        CallType callType,
        bytes calldata execData
    ) external view override returns (IERC20 token, bytes memory hookData) {
        (Call[] memory calls, bytes4 action, bytes memory actionData) = _decodeCalls(callType, execData);

        if (action == CREATE_ORDER) {
            IBaseOrderUtils.CreateOrderParams memory params =
                abi.decode(actionData, (IBaseOrderUtils.CreateOrderParams));

            if (_isIncreaseOrder(params.orderType)) {
                return _validateIncrease(subaccount, calls, params);
            } else if (_isDecreaseOrder(params.orderType)) {
                return _validateDecrease(subaccount, calls, params);
            }
            revert Error.GmxStage__InvalidOrderType();
        }

        if (action == CLAIM_FUNDING) {
            return _validateClaimFunding(subaccount, calls, actionData);
        }

        // TODO: handle CANCEL_ORDER, etc.
        revert Error.GmxStage__InvalidAction();
    }

    /// @notice Verify state after execution
    function verify(address, IERC20, uint, uint, bytes calldata) external pure override {}

    /// @notice Record position outcome
    function settle(address, bytes calldata) external override {}

    /// @notice Get position value in base token units
    /// @dev All GMX values are in USD (30 decimals), convert to base token at end
    function getPositionValue(bytes32 positionKey, IERC20 baseToken) external view override returns (uint) {
        uint collateralUsd = dataStore.getUint(keccak256(abi.encode(POSITION_COLLATERAL_AMOUNT, positionKey)));
        if (collateralUsd == 0) return 0;

        uint sizeInUsd = dataStore.getUint(keccak256(abi.encode(POSITION_SIZE_IN_USD, positionKey)));
        uint sizeInTokens = dataStore.getUint(keccak256(abi.encode(POSITION_SIZE_IN_TOKENS, positionKey)));
        bool isLong = dataStore.getBool(keccak256(abi.encode(POSITION_IS_LONG, positionKey)));
        address market = dataStore.getAddress(keccak256(abi.encode(POSITION_MARKET, positionKey)));

        // Calculate PnL in USD if position is open
        int256 pnlUsd;
        if (sizeInTokens > 0) {
            address indexToken = dataStore.getAddress(keccak256(abi.encode(MARKET_INDEX_TOKEN, market)));
            address indexFeed = dataStore.getAddress(keccak256(abi.encode(PRICE_FEED, indexToken)));
            if (indexFeed == address(0)) revert Error.GmxStage__MissingPriceFeed(indexToken);
            (, int256 indexPrice,,,) = IChainlinkAggregator(indexFeed).latestRoundData();
            if (indexPrice <= 0) revert Error.GmxStage__InvalidPrice(indexToken);

            // sizeInTokens * price * 10^(52-18) / 10^30 = currentValueUsd in 30 decimals
            uint currentValueUsd = sizeInTokens * uint(indexPrice) * 1e34 / 1e30;
            pnlUsd = isLong ? int256(currentValueUsd) - int256(sizeInUsd) : int256(sizeInUsd) - int256(currentValueUsd);
        }

        // Borrowing fees
        uint borrowingFeeUsd;
        uint posFactor = dataStore.getUint(keccak256(abi.encode(positionKey, BORROWING_FACTOR)));
        uint cumFactor = dataStore.getUint(keccak256(abi.encode(CUMULATIVE_BORROWING_FACTOR, market, isLong)));
        if (cumFactor > posFactor) {
            borrowingFeeUsd = sizeInUsd * (cumFactor - posFactor) / 1e30;
        }

        // Net value in USD
        int256 netValueUsd = int256(collateralUsd) + pnlUsd - int256(borrowingFeeUsd);
        if (netValueUsd <= 0) return 0;

        // Convert to base token amount
        address baseAddr = address(baseToken);
        address baseFeed = dataStore.getAddress(keccak256(abi.encode(PRICE_FEED, baseAddr)));
        if (baseFeed == address(0)) revert Error.GmxStage__MissingPriceFeed(baseAddr);
        (, int256 basePrice,,,) = IChainlinkAggregator(baseFeed).latestRoundData();
        if (basePrice <= 0) revert Error.GmxStage__InvalidPrice(baseAddr);

        uint8 baseDecimals = IERC20Metadata(baseAddr).decimals();
        return uint(netValueUsd) * (10 ** baseDecimals) / (uint(basePrice) * 1e22);
    }

    /// @notice Verify a position belongs to a subaccount
    /// @dev Checks GMX dataStore for position account
    function verifyPositionOwner(bytes32 positionKey, address subaccount) external view override returns (bool) {
        return dataStore.getAddress(keccak256(abi.encode(POSITION_ACCOUNT, positionKey))) == subaccount;
    }

    /// @notice Check if an order is still pending in GMX
    /// @dev Queries GMX's global ORDER_LIST (matches OrderStoreUtils.get check)
    function isOrderPending(bytes32 orderKey, address) external view override returns (bool) {
        return dataStore.containsBytes32(ORDER_LIST, orderKey);
    }

    // ============ Decode ============

    /// @dev Only CALLTYPE_SINGLE supported. Returns calls, action selector, and action data
    function _decodeCalls(CallType callType, bytes calldata execData)
        internal
        view
        returns (Call[] memory calls, bytes4 action, bytes memory actionData)
    {
        if (CallType.unwrap(callType) != CallType.unwrap(CALLTYPE_SINGLE)) revert Error.GmxStage__InvalidCallType();

        (address target, uint256 value, bytes calldata callData) = ExecutionLib.decodeSingle(execData);
        if (target != exchangeRouter) revert Error.GmxStage__InvalidTarget();

        bytes memory data = callData;
        bytes4 selector = _getSelector(data);

        // Multicall: decode inner bytes[] to Call[]
        if (selector == MULTICALL) {
            bytes[] memory innerCalls = abi.decode(_slice(data, 4), (bytes[]));
            calls = new Call[](innerCalls.length);

            for (uint i = 0; i < innerCalls.length; i++) {
                calls[i] = Call(exchangeRouter, 0, innerCalls[i]);
                bytes4 innerSelector = _getSelector(innerCalls[i]);

                // Identify action - only one allowed per multicall
                if (_isAction(innerSelector)) {
                    if (action != bytes4(0)) revert Error.GmxStage__InvalidCallData();
                    action = innerSelector;
                    actionData = _slice(innerCalls[i], 4);
                }
            }
        } else {
            // Direct call
            calls = new Call[](1);
            calls[0] = Call(target, value, callData);
            action = selector;
            actionData = _slice(data, 4);
        }

        if (action == bytes4(0)) revert Error.GmxStage__InvalidCallData();
    }

    // ============ Validators ============

    function _validateIncrease(
        address subaccount,
        Call[] memory calls,
        IBaseOrderUtils.CreateOrderParams memory params
    ) internal view returns (IERC20, bytes memory) {
        (bool hasExecutionFee, bool hasCollateral) = _validateCalls(calls);

        // Increase requires execution fee
        if (!hasExecutionFee) revert Error.GmxStage__InvalidExecutionSequence();

        // Collateral: WNT uses sendWnt (already counted), ERC20 requires sendTokens
        bool isWntCollateral = params.addresses.initialCollateralToken == wnt;
        if (!isWntCollateral && !hasCollateral) revert Error.GmxStage__InvalidExecutionSequence();

        _validateOrderParams(subaccount, params);

        IERC20 token = IERC20(params.addresses.initialCollateralToken);
        bytes32 orderKey = _deriveNextOrderKey();
        bytes32 positionKey = _derivePositionKey(subaccount, params);
        return (token, abi.encode(ACTION_ORDER_CREATED, orderKey, positionKey, token));
    }

    function _validateDecrease(
        address subaccount,
        Call[] memory calls,
        IBaseOrderUtils.CreateOrderParams memory params
    ) internal view returns (IERC20, bytes memory) {
        (bool hasExecutionFee,) = _validateCalls(calls);

        // Decrease requires execution fee
        if (!hasExecutionFee) revert Error.GmxStage__InvalidExecutionSequence();

        _validateOrderParams(subaccount, params);

        IERC20 token = IERC20(params.addresses.initialCollateralToken);
        bytes32 orderKey = _deriveNextOrderKey();
        bytes32 positionKey = _derivePositionKey(subaccount, params);
        return (token, abi.encode(ACTION_ORDER_CREATED, orderKey, positionKey, token));
    }

    function _validateCalls(Call[] memory calls) internal view returns (bool hasExecutionFee, bool hasCollateral) {
        for (uint i = 0; i < calls.length; i++) {
            if (calls[i].target != exchangeRouter) revert Error.GmxStage__InvalidCallData();

            bytes4 selector = _getSelector(calls[i].data);

            if (selector == SEND_WNT) {
                (address receiver,) = abi.decode(_slice(calls[i].data, 4), (address, uint));
                if (receiver == orderVault) hasExecutionFee = true;
            } else if (selector == SEND_TOKENS) {
                (, address receiver,) = abi.decode(_slice(calls[i].data, 4), (address, address, uint));
                if (receiver == orderVault) hasCollateral = true;
            }
        }
    }

    function _validateClaimFunding(
        address subaccount,
        Call[] memory calls,
        bytes memory actionData
    ) internal view returns (IERC20, bytes memory) {
        // claimFundingFees(address[] markets, address[] tokens, address receiver)
        (,, address receiver) = abi.decode(actionData, (address[], address[], address));

        if (receiver != subaccount) revert Error.GmxStage__InvalidReceiver();

        // Validate all calls target exchangeRouter
        for (uint i = 0; i < calls.length; i++) {
            if (calls[i].target != exchangeRouter) revert Error.GmxStage__InvalidCallData();
        }

        // Claims may involve multiple tokens - no specific token tracking
        return (IERC20(address(0)), "");
    }

    function _slice(bytes memory data, uint start) internal pure returns (bytes memory) {
        bytes memory result = new bytes(data.length - start);
        for (uint i = 0; i < result.length; i++) {
            result[i] = data[start + i];
        }
        return result;
    }

    function _validateOrderParams(
        address subaccount,
        IBaseOrderUtils.CreateOrderParams memory params
    ) internal pure {
        if (params.addresses.receiver != subaccount) revert Error.GmxStage__InvalidReceiver();
        if (params.addresses.cancellationReceiver != address(0)) {
            if (params.addresses.cancellationReceiver != subaccount) revert Error.GmxStage__InvalidReceiver();
        }
        // Token choice is validated at deposit time via tokenCapMap whitelist
        if (params.addresses.swapPath.length > 0) revert Error.GmxStage__InvalidOrderType();
    }

    // ============ Helpers ============

    function _isAction(bytes4 selector) internal view returns (bool) {
        return selector == CREATE_ORDER ||
               selector == CANCEL_ORDER ||
               selector == CLAIM_FUNDING;
    }

    function _isIncreaseOrder(Order.OrderType orderType) internal pure returns (bool) {
        return orderType == Order.OrderType.MarketIncrease ||
               orderType == Order.OrderType.LimitIncrease ||
               orderType == Order.OrderType.StopIncrease;
    }

    function _isDecreaseOrder(Order.OrderType orderType) internal pure returns (bool) {
        return orderType == Order.OrderType.MarketDecrease ||
               orderType == Order.OrderType.LimitDecrease ||
               orderType == Order.OrderType.StopLossDecrease;
    }

    /// @notice Derive the next orderKey that GMX will assign
    /// @dev GMX derives orderKey as keccak256(abi.encode(dataStore, nonce + 1))
    /// Same transaction guarantees this is the exact key
    function _deriveNextOrderKey() internal view returns (bytes32) {
        uint256 currentNonce = dataStore.getUint(NONCE_KEY);
        return keccak256(abi.encode(dataStore, currentNonce + 1));
    }

    /// @notice Derive GMX position key
    /// @dev Matches GMX's PositionStoreUtils key derivation
    function _derivePositionKey(address subaccount, IBaseOrderUtils.CreateOrderParams memory params)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(
            subaccount,
            params.addresses.market,
            params.addresses.initialCollateralToken,
            params.isLong
        ));
    }

    function _getSelector(bytes memory data) internal pure returns (bytes4 selector) {
        if (data.length < 4) revert Error.GmxStage__InvalidCallData();
        assembly {
            selector := mload(add(data, 32))
        }
    }
}
