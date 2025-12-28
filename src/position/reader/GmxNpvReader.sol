// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {Permission} from "../../utils/auth/Permission.sol";
import {IAuthority} from "../../utils/interfaces/IAuthority.sol";
import {INpvReader} from "../interface/INpvReader.sol";

import {Position} from "gmx-synthetics/position/Position.sol";
import {Market} from "gmx-synthetics/market/Market.sol";
import {Price} from "gmx-synthetics/price/Price.sol";

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
    ) external view returns (PositionInfo memory);
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

struct PositionInfo {
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
 * @title GmxNpvReader
 * @notice GMX V2 implementation for reading position Net Value
 * @dev Net Value = collateral + PnL - fees (in collateral token units)
 */
contract GmxNpvReader is INpvReader {
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

    // ============ Errors ============

    error InvalidFeedPrice(address token, int256 price);
    error ChainlinkPriceFeedNotUpdated(address token, uint256 timestamp, uint256 heartbeatDuration);
    error EmptyPriceFeedMultiplier(address token);
    error NoPriceFeed(address token);

    // ============ Constructor ============

    constructor(
        address _dataStore,
        address _reader,
        address _referralStorage
    ) {
        dataStore = IGmxDataStore(_dataStore);
        reader = IGmxReader(_reader);
        referralStorage = _referralStorage;
    }

    // ============ External ============

    /// @inheritdoc INpvReader
    function getPositionNetValue(bytes32 _positionKey) external view returns (uint256 netValue) {
        Position.Props memory pos = reader.getPosition(address(dataStore), _positionKey);
        if (pos.numbers.sizeInUsd == 0) return 0;

        Market.Props memory market = reader.getMarket(address(dataStore), pos.addresses.market);
        MarketPrices memory prices = _buildMarketPrices(market);

        PositionInfo memory info = reader.getPositionInfo(
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

    // ============ Position Call Parsing ============

    bytes4 private constant CREATE_ORDER = 0x4a393149;
    uint256 private constant ORDER_TYPE_MARKET_INCREASE = 2;
    uint256 private constant ORDER_TYPE_LIMIT_INCREASE = 3;

    function parsePositionCall(address _account, bytes calldata _callData) external pure returns (INpvReader.PositionCallInfo memory _info) {
        if (_callData.length < 4) return _info;
        if (bytes4(_callData[:4]) != CREATE_ORDER) return _info;

        bytes calldata _params = _callData[4:];

        uint256 addressesOffset = abi.decode(_params[:32], (uint256));
        uint256 numbersOffset = abi.decode(_params[32:64], (uint256));

        address market = abi.decode(_params[addressesOffset + 128:addressesOffset + 160], (address));
        _info.collateralToken = abi.decode(_params[addressesOffset + 160:addressesOffset + 192], (address));

        _info.sizeDelta = abi.decode(_params[numbersOffset:numbersOffset + 32], (uint256));
        _info.collateralDelta = abi.decode(_params[numbersOffset + 32:numbersOffset + 64], (uint256));

        uint256 orderType = abi.decode(_params[64:96], (uint256));
        bool isLong = abi.decode(_params[128:160], (bool));

        _info.isIncrease = (orderType == ORDER_TYPE_MARKET_INCREASE || orderType == ORDER_TYPE_LIMIT_INCREASE);
        _info.positionKey = keccak256(abi.encode(_account, market, _info.collateralToken, isLong));
    }
}
