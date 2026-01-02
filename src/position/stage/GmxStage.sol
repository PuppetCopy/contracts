// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {CallType, CALLTYPE_SINGLE} from "modulekit/accounts/common/lib/ModeLib.sol";
import {ExecutionLib} from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import {IExchangeRouter} from "gmx-synthetics/router/IExchangeRouter.sol";

import {IBaseOrderUtils} from "gmx-synthetics/order/IBaseOrderUtils.sol";
import {Order} from "gmx-synthetics/order/Order.sol";

import {IStage, Call} from "../interface/IStage.sol";
import {IGmxDataStore} from "../interface/IGmxDataStore.sol";
import {Error} from "../../utils/Error.sol";

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

    /// @notice Get position collateral value
    function getValue(bytes32 positionKey) external view override returns (uint) {
        bytes32 key = keccak256(abi.encode(keccak256("POSITION_COLLATERAL_AMOUNT"), positionKey));
        return dataStore.getUint(key);
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
        bytes32 positionKey = _derivePositionKey(subaccount, params);
        return (token, abi.encode(positionKey));
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
        bytes32 positionKey = _derivePositionKey(subaccount, params);
        return (token, abi.encode(positionKey));
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
