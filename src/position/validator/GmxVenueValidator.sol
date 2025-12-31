// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC7579Account} from "modulekit/accounts/common/interfaces/IERC7579Account.sol";

import {Position} from "gmx-synthetics/position/Position.sol";
import {Market} from "gmx-synthetics/market/Market.sol";
import {Price} from "gmx-synthetics/price/Price.sol";
import {Order} from "gmx-synthetics/order/Order.sol";
import {IBaseOrderUtils} from "gmx-synthetics/order/IBaseOrderUtils.sol";
import {IExchangeRouter} from "gmx-synthetics/router/IExchangeRouter.sol";

import {Permission} from "../../utils/auth/Permission.sol";
import {IAuthority} from "../../utils/interfaces/IAuthority.sol";
import {IVenueValidator} from "../interface/IVenueValidator.sol";
import {Error} from "../../utils/Error.sol";


interface IReferralStorageByUser {
    function setTraderReferralCodeByUser(bytes32 _code) external;
}

// ============ Interfaces ============

interface IGmxDataStore {
    function getAddress(bytes32 key) external view returns (address);
    function getUint(bytes32 key) external view returns (uint256);
}

interface IGmxReader {
    function getMarket(address dataStore, address key) external view returns (Market.Props memory);
    function getPosition(address dataStore, bytes32 positionKey) external view returns (Position.Props memory);
    function getPositionInfo(
        address dataStore,
        address referralStorage,
        bytes32 positionKey,
        MarketPrices memory prices,
        uint256 sizeDeltaUsd,
        address uiFeeReceiver,
        bool usePositionSizeAsSizeDeltaUsd
    ) external view returns (GmxPositionInfo memory);
}

interface IPriceFeed {
    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80);
}

// ============ GMX Structs ============

struct MarketPrices {
    Price.Props indexTokenPrice;
    Price.Props longTokenPrice;
    Price.Props shortTokenPrice;
}

struct GmxPositionInfo {
    bytes32 positionKey;
    Position.Props position;
    PositionFees fees;
    ExecutionPriceResult executionPriceResult;
    int256 basePnlUsd;
    int256 uncappedBasePnlUsd;
    int256 pnlAfterPriceImpactUsd;
}

struct PositionFees {
    PositionReferralFees referral;
    PositionProFees pro;
    PositionFundingFees funding;
    PositionBorrowingFees borrowing;
    PositionUiFees ui;
    PositionLiquidationFees liquidation;
    Price.Props collateralTokenPrice;
    uint256 positionFeeFactor;
    uint256 protocolFeeAmount;
    uint256 positionFeeReceiverFactor;
    uint256 feeReceiverAmount;
    uint256 feeAmountForPool;
    uint256 positionFeeAmountForPool;
    uint256 positionFeeAmount;
    uint256 totalCostAmountExcludingFunding;
    uint256 totalCostAmount;
    uint256 totalDiscountAmount;
}

struct PositionReferralFees {
    bytes32 referralCode;
    address affiliate;
    address trader;
    uint256 totalRebateFactor;
    uint256 affiliateRewardFactor;
    uint256 adjustedAffiliateRewardFactor;
    uint256 traderDiscountFactor;
    uint256 totalRebateAmount;
    uint256 traderDiscountAmount;
    uint256 affiliateRewardAmount;
}

struct PositionProFees {
    uint256 traderTier;
    uint256 traderDiscountFactor;
    uint256 traderDiscountAmount;
}

struct PositionFundingFees {
    uint256 fundingFeeAmount;
    uint256 claimableLongTokenAmount;
    uint256 claimableShortTokenAmount;
    uint256 latestFundingFeeAmountPerSize;
    uint256 latestLongTokenClaimableFundingAmountPerSize;
    uint256 latestShortTokenClaimableFundingAmountPerSize;
}

struct PositionBorrowingFees {
    uint256 borrowingFeeUsd;
    uint256 borrowingFeeAmount;
    uint256 borrowingFeeReceiverFactor;
    uint256 borrowingFeeAmountForFeeReceiver;
}

struct PositionUiFees {
    address uiFeeReceiver;
    uint256 uiFeeReceiverFactor;
    uint256 uiFeeAmount;
}

struct PositionLiquidationFees {
    uint256 liquidationFeeUsd;
    uint256 liquidationFeeAmount;
    uint256 liquidationFeeReceiverFactor;
    uint256 liquidationFeeAmountForFeeReceiver;
}

struct ExecutionPriceResult {
    int256 priceImpactUsd;
    uint256 executionPrice;
    bool balanceWasImproved;
    int256 proportionalPendingImpactUsd;
    int256 totalImpactUsd;
    uint256 priceImpactDiffUsd;
}

/**
 * @title GmxVenueValidator
 * @notice GMX V2 venue validator for parsing calls and reading position Net Value
 * @dev Net Value = collateral + PnL - fees (in collateral token units)
 */
contract GmxVenueValidator is IVenueValidator {
    // ============ Constants ============

    uint256 private constant FLOAT_PRECISION = 1e30;

    // GMX DataStore keys
    bytes32 private constant PRICE_FEED = keccak256(abi.encode("PRICE_FEED"));
    bytes32 private constant PRICE_FEED_MULTIPLIER = keccak256(abi.encode("PRICE_FEED_MULTIPLIER"));
    bytes32 private constant PRICE_FEED_HEARTBEAT_DURATION = keccak256(abi.encode("PRICE_FEED_HEARTBEAT_DURATION"));

    // ============ State ============

    IGmxDataStore public immutable dataStore;
    IGmxReader public immutable reader;
    address public immutable referralStorage;
    address public immutable router;

    // ============ Errors ============

    error InvalidFeedPrice(address token, int256 price);
    error ChainlinkPriceFeedNotUpdated(address token, uint256 timestamp, uint256 heartbeatDuration);
    error EmptyPriceFeedMultiplier(address token);
    error NoPriceFeed(address token);

    // ============ Constructor ============

    constructor(
        address _dataStore,
        address _reader,
        address _referralStorage,
        address _router
    ) {
        dataStore = IGmxDataStore(_dataStore);
        reader = IGmxReader(_reader);
        referralStorage = _referralStorage;
        router = _router;
    }

    // ============ External ============

    /// @inheritdoc IVenueValidator
    function getPositionNetValue(bytes32 _positionKey) external view returns (uint256 netValue) {
        Position.Props memory pos = reader.getPosition(address(dataStore), _positionKey);
        if (pos.numbers.sizeInUsd == 0) return 0;

        Market.Props memory market = reader.getMarket(address(dataStore), pos.addresses.market);
        MarketPrices memory prices = _buildMarketPrices(market);

        GmxPositionInfo memory info = reader.getPositionInfo(
            address(dataStore), referralStorage, _positionKey, prices, 0, address(0), true
        );

        Price.Props memory collateralPrice =
            pos.addresses.collateralToken == market.longToken ? prices.longTokenPrice : prices.shortTokenPrice;

        int256 pnlInTokens = 0;
        if (collateralPrice.min > 0) {
            pnlInTokens =
                (info.basePnlUsd * int256(FLOAT_PRECISION)) / int256(collateralPrice.min) / int256(FLOAT_PRECISION);
        }

        int256 _value = int256(pos.numbers.collateralAmount) + pnlInTokens - int256(info.fees.totalCostAmount);
        netValue = _value > 0 ? uint256(_value) : 0;
    }

    // ============ Internal: Price Building ============

    function _buildMarketPrices(Market.Props memory _market) internal view returns (MarketPrices memory prices) {
        prices.indexTokenPrice = _toMarketPrice(_getPriceFeedPrice(_market.indexToken));

        if (_market.longToken == _market.indexToken) {
            prices.longTokenPrice = prices.indexTokenPrice;
        } else {
            prices.longTokenPrice = _toMarketPrice(_getPriceFeedPrice(_market.longToken));
        }

        if (_market.shortToken == _market.indexToken) {
            prices.shortTokenPrice = prices.indexTokenPrice;
        } else if (_market.shortToken == _market.longToken) {
            prices.shortTokenPrice = prices.longTokenPrice;
        } else {
            prices.shortTokenPrice = _toMarketPrice(_getPriceFeedPrice(_market.shortToken));
        }
    }

    function _toMarketPrice(uint256 _price) internal pure returns (Price.Props memory) {
        return Price.Props(_price, _price);
    }

    // ============ Internal: Chainlink ============

    /// @dev Replicates ChainlinkPriceFeedUtils.getPriceFeedPrice
    function _getPriceFeedPrice(address _token) internal view returns (uint256) {
        address feed = dataStore.getAddress(keccak256(abi.encode(PRICE_FEED, _token)));
        if (feed == address(0)) revert NoPriceFeed(_token);

        (, int256 price,, uint256 timestamp,) = IPriceFeed(feed).latestRoundData();
        if (price <= 0) revert InvalidFeedPrice(_token, price);

        uint256 heartbeat = dataStore.getUint(keccak256(abi.encode(PRICE_FEED_HEARTBEAT_DURATION, _token)));
        if (block.timestamp > timestamp && block.timestamp - timestamp > heartbeat) {
            revert ChainlinkPriceFeedNotUpdated(_token, timestamp, heartbeat);
        }

        uint256 multiplier = dataStore.getUint(keccak256(abi.encode(PRICE_FEED_MULTIPLIER, _token)));
        if (multiplier == 0) revert EmptyPriceFeedMultiplier(_token);

        return (uint256(price) * multiplier) / FLOAT_PRECISION;
    }

    // ============ Validation ============

    bytes4 private constant APPROVE_SELECTOR = bytes4(keccak256("approve(address,uint256)"));
    bytes4 private constant MULTICALL_SELECTOR = bytes4(keccak256("multicall(bytes[])"));
    bytes4 private constant CREATE_ORDER_SELECTOR = IExchangeRouter.createOrder.selector;
    bytes4 private constant UPDATE_ORDER_SELECTOR = IExchangeRouter.updateOrder.selector;
    bytes4 private constant CANCEL_ORDER_SELECTOR = IExchangeRouter.cancelOrder.selector;
    bytes4 private constant SEND_WNT_SELECTOR = bytes4(keccak256("sendWnt(address,uint256)"));
    bytes4 private constant SEND_TOKENS_SELECTOR = bytes4(keccak256("sendTokens(address,address,uint256)"));
    bytes4 private constant CLAIM_FUNDING_FEES_SELECTOR = bytes4(keccak256("claimFundingFees(address[],address[],address)"));
    bytes4 private constant CLAIM_COLLATERAL_SELECTOR = bytes4(keccak256("claimCollateral(address[],address[],uint256[],address)"));
    bytes4 private constant SET_REFERRAL_SELECTOR = IReferralStorageByUser.setTraderReferralCodeByUser.selector;

    /// @inheritdoc IVenueValidator
    function validate(
        IERC7579Account _subaccount,
        IERC20 _token,
        uint256 _amount,
        bytes calldata _callData
    ) external view override {
        if (_callData.length < 4) revert Error.GmxVenueValidator__InvalidCallData();

        bytes4 selector = bytes4(_callData[:4]);

        // Hot path: approve (for token approvals to GMX router - uses max uint)
        if (selector == APPROVE_SELECTOR) {
            (address spender,) = abi.decode(_callData[4:], (address, uint256));
            if (spender != router) revert Error.GmxVenueValidator__InvalidReceiver();
            return;
        }

        // Hot path: multicall (GMX batches sendWnt + sendTokens + createOrder)
        if (selector == MULTICALL_SELECTOR) {
            bytes[] memory calls = abi.decode(_callData[4:], (bytes[]));
            bool hasCreateOrder = false;

            for (uint256 i = 0; i < calls.length; i++) {
                if (calls[i].length < 4) revert Error.GmxVenueValidator__InvalidCallData();
                bytes4 innerSelector = bytes4(calls[i]);

                // sendWnt: sends ETH execution fee to orderVault - validate receiver
                if (innerSelector == SEND_WNT_SELECTOR) {
                    // sendWnt(address receiver, uint256 amount) - receiver should be order vault, amount is execution fee
                    continue;
                }

                // sendTokens: sends collateral to orderVault - validate token and receiver
                if (innerSelector == SEND_TOKENS_SELECTOR) {
                    // sendTokens(address token, address receiver, uint256 amount)
                    (address token,,) = abi.decode(_slice(calls[i], 4), (address, address, uint256));
                    if (token != address(_token)) {
                        revert Error.GmxVenueValidator__TokenMismatch(address(_token), token);
                    }
                    continue;
                }

                // createOrder: validate order params
                if (innerSelector == CREATE_ORDER_SELECTOR) {
                    _validateCreateOrder(_subaccount, _token, _amount, _slice(calls[i], 4));
                    hasCreateOrder = true;
                    continue;
                }

                // Unknown selector in multicall
                revert Error.GmxVenueValidator__InvalidCallData();
            }

            // Multicall must contain createOrder
            if (!hasCreateOrder) revert Error.GmxVenueValidator__InvalidCallData();
            return;
        }

        // Hot path: createOrder (increase or decrease)
        if (selector == CREATE_ORDER_SELECTOR) {
            _validateCreateOrder(_subaccount, _token, _amount, _callData[4:]);
            return;
        }

        // Cold path: order management (no token transfer)
        if (selector == UPDATE_ORDER_SELECTOR || selector == CANCEL_ORDER_SELECTOR) {
            if (_amount != 0) revert Error.GmxVenueValidator__AmountMismatch(0, _amount);
            return;
        }

        // Cold path: claim funding fees (receiver must be subaccount)
        if (selector == CLAIM_FUNDING_FEES_SELECTOR) {
            if (_amount != 0) revert Error.GmxVenueValidator__AmountMismatch(0, _amount);
            (,, address receiver) = abi.decode(_callData[4:], (address[], address[], address));
            if (receiver != address(_subaccount)) revert Error.GmxVenueValidator__InvalidReceiver();
            return;
        }

        // Cold path: claim collateral (receiver must be subaccount)
        if (selector == CLAIM_COLLATERAL_SELECTOR) {
            if (_amount != 0) revert Error.GmxVenueValidator__AmountMismatch(0, _amount);
            (,,, address receiver) = abi.decode(_callData[4:], (address[], address[], uint256[], address));
            if (receiver != address(_subaccount)) revert Error.GmxVenueValidator__InvalidReceiver();
            return;
        }

        // Cold path: setTraderReferralCodeByUser (one-time setup)
        if (selector == SET_REFERRAL_SELECTOR) {
            if (_amount != 0) revert Error.GmxVenueValidator__AmountMismatch(0, _amount);
            return;
        }

        revert Error.GmxVenueValidator__InvalidCallData();
    }

    /// @dev Validate createOrder params
    function _validateCreateOrder(
        IERC7579Account _subaccount,
        IERC20 _token,
        uint256 _amount,
        bytes memory _data
    ) internal view {
        IBaseOrderUtils.CreateOrderParams memory params =
            abi.decode(_data, (IBaseOrderUtils.CreateOrderParams));

        // Receiver must be the subaccount to prevent fund redirection
        if (params.addresses.receiver != address(_subaccount)) {
            revert Error.GmxVenueValidator__InvalidReceiver();
        }

        // Cancellation receiver must be subaccount or zero (defaults to account)
        if (params.addresses.cancellationReceiver != address(0) &&
            params.addresses.cancellationReceiver != address(_subaccount)) {
            revert Error.GmxVenueValidator__InvalidReceiver();
        }

        // No callbacks allowed - prevents arbitrary contract execution
        if (params.addresses.callbackContract != address(0)) {
            revert Error.GmxVenueValidator__InvalidCallData();
        }

        // Collateral token must match for all orders
        if (params.addresses.initialCollateralToken != address(_token)) {
            revert Error.GmxVenueValidator__TokenMismatch(address(_token), params.addresses.initialCollateralToken);
        }

        // Increase: validate amount, Decrease: no deposit
        if (Order.isIncreaseOrder(params.orderType)) {
            if (params.numbers.initialCollateralDeltaAmount != _amount) {
                revert Error.GmxVenueValidator__AmountMismatch(_amount, params.numbers.initialCollateralDeltaAmount);
            }
        } else if (Order.isDecreaseOrder(params.orderType)) {
            if (_amount != 0) revert Error.GmxVenueValidator__AmountMismatch(0, _amount);
        } else {
            revert Error.GmxVenueValidator__InvalidOrderType();
        }
    }

    /// @dev Slice bytes starting from offset
    function _slice(bytes memory _data, uint256 _start) internal pure returns (bytes memory) {
        require(_start <= _data.length, "slice_outOfBounds");
        bytes memory result = new bytes(_data.length - _start);
        for (uint256 i = 0; i < result.length; i++) {
            result[i] = _data[_start + i];
        }
        return result;
    }

    /// @inheritdoc IVenueValidator
    function getPositionInfo(
        IERC7579Account _subaccount,
        bytes calldata _callData
    ) external view returns (IVenueValidator.PositionInfo memory _info) {
        if (_callData.length < 4) return _info; // Return empty for invalid calldata

        bytes4 selector = bytes4(_callData[:4]);

        // Handle multicall: extract createOrder from inner calls
        if (selector == MULTICALL_SELECTOR) {
            bytes[] memory calls = abi.decode(_callData[4:], (bytes[]));
            for (uint256 i = 0; i < calls.length; i++) {
                if (calls[i].length >= 4 && bytes4(calls[i]) == CREATE_ORDER_SELECTOR) {
                    return _getPositionInfoFromParams(_subaccount, abi.decode(_slice(calls[i], 4), (IBaseOrderUtils.CreateOrderParams)));
                }
            }
            return _info; // No createOrder found in multicall
        }

        // Only createOrder calls have position info
        if (selector != CREATE_ORDER_SELECTOR) {
            return _info; // Return empty for approve, updateOrder, cancelOrder, etc.
        }

        IBaseOrderUtils.CreateOrderParams memory params =
            abi.decode(_callData[4:], (IBaseOrderUtils.CreateOrderParams));
        return _getPositionInfoFromParams(_subaccount, params);
    }

    /// @dev Build position info from order params
    function _getPositionInfoFromParams(
        IERC7579Account _subaccount,
        IBaseOrderUtils.CreateOrderParams memory params
    ) internal view returns (IVenueValidator.PositionInfo memory _info) {

        bytes32 positionKey = keccak256(
            abi.encode(
                address(_subaccount),
                params.addresses.market,
                params.addresses.initialCollateralToken,
                params.isLong
            )
        );

        _info.positionKey = positionKey;
        _info.netValue = this.getPositionNetValue(positionKey);
    }

    /// @notice Decode createOrder calldata into CreateOrderParams
    function _decodeCreateOrder(
        bytes calldata _callData
    ) internal pure returns (IBaseOrderUtils.CreateOrderParams memory params) {
        if (_callData.length < 4) revert Error.GmxVenueValidator__InvalidCallData();
        bytes4 selector = bytes4(_callData[:4]);
        if (selector != CREATE_ORDER_SELECTOR) revert Error.GmxVenueValidator__InvalidCallData();

        params = abi.decode(_callData[4:], (IBaseOrderUtils.CreateOrderParams));
    }

    /// @notice Get the referral code from createOrder calldata
    function getReferralCode(bytes calldata _callData) external pure returns (bytes32) {
        return _decodeCreateOrder(_callData).referralCode;
    }
}
