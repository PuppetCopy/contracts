// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC7579Account} from "modulekit/accounts/common/interfaces/IERC7579Account.sol";
import {CallType, CALLTYPE_SINGLE} from "modulekit/accounts/common/lib/ModeLib.sol";
import {ExecutionLib} from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import {IExchangeRouter} from "gmx-synthetics/router/IExchangeRouter.sol";

import {IBaseOrderUtils} from "gmx-synthetics/order/IBaseOrderUtils.sol";
import {Order} from "gmx-synthetics/order/Order.sol";

import {IStage, Call, Action} from "../interface/IStage.sol";
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


    // ============ Immutables ============

    IGmxDataStore public immutable dataStore;
    address public immutable exchangeRouter;
    address public immutable orderVault;
    IERC20 public immutable wnt;

    // ============ Constructor ============

    constructor(address _dataStore, address _exchangeRouter, address _orderVault, IERC20 _wnt) {
        dataStore = IGmxDataStore(_dataStore);
        exchangeRouter = _exchangeRouter;
        orderVault = _orderVault;
        wnt = _wnt;
    }

    // ============ IStage Implementation ============

    function getAction(
        address,
        IERC7579Account _master,
        IERC20,
        uint,
        CallType _callType,
        bytes calldata _execData
    ) external view override returns (Action memory _result) {
        (Call[] memory _calls, bytes4 _action, bytes memory _actionData) = _decodeCalls(_callType, _execData);

        if (_action == CREATE_ORDER) {
            IBaseOrderUtils.CreateOrderParams memory _params =
                abi.decode(_actionData, (IBaseOrderUtils.CreateOrderParams));

            if (_isIncreaseOrder(_params.orderType)) {
                return _validateIncrease(_master, _calls, _params);
            } else if (_isDecreaseOrder(_params.orderType)) {
                return _validateDecrease(_master, _calls, _params);
            }
            revert Error.GmxStage__InvalidOrderType();
        }

        if (_action == CLAIM_FUNDING) {
            return _validateClaimFunding(_master, _calls, _actionData);
        }

        // TODO: handle CANCEL_ORDER, etc.
        revert Error.GmxStage__InvalidAction();
    }

    function verify(IERC7579Account, IERC20, uint, uint, bytes calldata) external pure override {}

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

    function verifyPositionOwner(bytes32 positionKey, IERC7579Account master) external view override returns (bool) {
        return dataStore.getAddress(keccak256(abi.encode(POSITION_ACCOUNT, positionKey))) == address(master);
    }

    function isOrderPending(bytes32 orderKey, IERC7579Account) external view override returns (bool) {
        return dataStore.containsBytes32(ORDER_LIST, orderKey);
    }

    // ============ Decode ============

    /// @dev Only CALLTYPE_SINGLE supported. Returns calls, action selector, and action data
    function _decodeCalls(CallType _callType, bytes calldata _execData)
        internal
        view
        returns (Call[] memory _calls, bytes4 _action, bytes memory _actionData)
    {
        if (CallType.unwrap(_callType) != CallType.unwrap(CALLTYPE_SINGLE)) revert Error.GmxStage__InvalidCallType();

        (address _target, uint256 _value, bytes calldata _callData) = ExecutionLib.decodeSingle(_execData);
        if (_target != exchangeRouter) revert Error.GmxStage__InvalidTarget();

        bytes memory _data = _callData;
        bytes4 _selector = _getSelector(_data);

        // Multicall: decode inner bytes[] to Call[]
        if (_selector == MULTICALL) {
            bytes[] memory _innerCalls = abi.decode(_slice(_data, 4), (bytes[]));
            _calls = new Call[](_innerCalls.length);

            for (uint _i = 0; _i < _innerCalls.length; _i++) {
                _calls[_i] = Call(exchangeRouter, 0, _innerCalls[_i]);
                bytes4 _innerSelector = _getSelector(_innerCalls[_i]);

                // Identify action - only one allowed per multicall
                if (_isAction(_innerSelector)) {
                    if (_action != bytes4(0)) revert Error.GmxStage__InvalidCallData();
                    _action = _innerSelector;
                    _actionData = _slice(_innerCalls[_i], 4);
                }
            }
        } else {
            // Direct call
            _calls = new Call[](1);
            _calls[0] = Call(_target, _value, _callData);
            _action = _selector;
            _actionData = _slice(_data, 4);
        }

        if (_action == bytes4(0)) revert Error.GmxStage__InvalidCallData();
    }

    // ============ Validators ============

    function _validateIncrease(
        IERC7579Account _master,
        Call[] memory _calls,
        IBaseOrderUtils.CreateOrderParams memory _params
    ) internal view returns (Action memory) {
        (bool _hasExecutionFee, bool _hasCollateral) = _validateCalls(_calls);

        if (!_hasExecutionFee) revert Error.GmxStage__InvalidExecutionSequence();

        bool _isWntCollateral = _params.addresses.initialCollateralToken == address(wnt);
        if (!_isWntCollateral && !_hasCollateral) revert Error.GmxStage__InvalidExecutionSequence();

        _validateOrderParams(_master, _params);

        bytes32 _orderKey = _deriveNextOrderKey();
        bytes32 _positionKey = _derivePositionKey(_master, _params);

        return Action({
            actionType: CREATE_ORDER,
            data: abi.encode(_orderKey, _positionKey)
        });
    }

    function _validateDecrease(
        IERC7579Account _master,
        Call[] memory _calls,
        IBaseOrderUtils.CreateOrderParams memory _params
    ) internal view returns (Action memory) {
        (bool _hasExecutionFee,) = _validateCalls(_calls);

        if (!_hasExecutionFee) revert Error.GmxStage__InvalidExecutionSequence();

        _validateOrderParams(_master, _params);

        bytes32 _orderKey = _deriveNextOrderKey();
        bytes32 _positionKey = _derivePositionKey(_master, _params);

        return Action({
            actionType: CREATE_ORDER,
            data: abi.encode(_orderKey, _positionKey)
        });
    }

    function _validateCalls(Call[] memory _calls) internal view returns (bool _hasExecutionFee, bool _hasCollateral) {
        for (uint _i = 0; _i < _calls.length; _i++) {
            if (_calls[_i].target != exchangeRouter) revert Error.GmxStage__InvalidCallData();

            bytes4 _selector = _getSelector(_calls[_i].data);

            if (_selector == SEND_WNT) {
                (address _receiver,) = abi.decode(_slice(_calls[_i].data, 4), (address, uint));
                if (_receiver == orderVault) _hasExecutionFee = true;
            } else if (_selector == SEND_TOKENS) {
                (, address _receiver,) = abi.decode(_slice(_calls[_i].data, 4), (address, address, uint));
                if (_receiver == orderVault) _hasCollateral = true;
            }
        }
    }

    function _validateClaimFunding(
        IERC7579Account _master,
        Call[] memory _calls,
        bytes memory _actionData
    ) internal view returns (Action memory) {
        (address[] memory _marketList, address[] memory _tokenList, address _receiver) =
            abi.decode(_actionData, (address[], address[], address));

        if (_receiver != address(_master)) revert Error.GmxStage__InvalidReceiver();

        for (uint _i = 0; _i < _calls.length; _i++) {
            if (_calls[_i].target != exchangeRouter) revert Error.GmxStage__InvalidCallData();
        }

        return Action({
            actionType: CLAIM_FUNDING,
            data: abi.encode(_marketList, _tokenList)
        });
    }

    function _slice(bytes memory _data, uint _start) internal pure returns (bytes memory) {
        bytes memory _result = new bytes(_data.length - _start);
        for (uint _i = 0; _i < _result.length; _i++) {
            _result[_i] = _data[_start + _i];
        }
        return _result;
    }

    function _validateOrderParams(
        IERC7579Account _master,
        IBaseOrderUtils.CreateOrderParams memory _params
    ) internal pure {
        if (_params.addresses.receiver != address(_master)) revert Error.GmxStage__InvalidReceiver();
        if (_params.addresses.cancellationReceiver != address(0)) {
            if (_params.addresses.cancellationReceiver != address(_master)) revert Error.GmxStage__InvalidReceiver();
        }
        if (_params.addresses.swapPath.length > 0) revert Error.GmxStage__InvalidOrderType();
    }

    // ============ Helpers ============

    function _isAction(bytes4 _selector) internal view returns (bool) {
        return _selector == CREATE_ORDER ||
               _selector == CANCEL_ORDER ||
               _selector == CLAIM_FUNDING;
    }

    function _isIncreaseOrder(Order.OrderType _orderType) internal pure returns (bool) {
        return _orderType == Order.OrderType.MarketIncrease ||
               _orderType == Order.OrderType.LimitIncrease ||
               _orderType == Order.OrderType.StopIncrease;
    }

    function _isDecreaseOrder(Order.OrderType _orderType) internal pure returns (bool) {
        return _orderType == Order.OrderType.MarketDecrease ||
               _orderType == Order.OrderType.LimitDecrease ||
               _orderType == Order.OrderType.StopLossDecrease;
    }

    /// @notice Derive the next orderKey that GMX will assign
    /// @dev GMX derives orderKey as keccak256(abi.encode(dataStore, nonce + 1))
    /// Same transaction guarantees this is the exact key
    function _deriveNextOrderKey() internal view returns (bytes32) {
        uint256 _currentNonce = dataStore.getUint(NONCE_KEY);
        return keccak256(abi.encode(dataStore, _currentNonce + 1));
    }

    function _derivePositionKey(IERC7579Account _master, IBaseOrderUtils.CreateOrderParams memory _params)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(
            address(_master),
            _params.addresses.market,
            _params.addresses.initialCollateralToken,
            _params.isLong
        ));
    }

    function _getSelector(bytes memory _data) internal pure returns (bytes4 _selector) {
        if (_data.length < 4) revert Error.GmxStage__InvalidCallData();
        assembly {
            _selector := mload(add(_data, 32))
        }
    }
}
