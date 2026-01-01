// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice Structured input for stage operations
struct Order {
    bytes32 stage;       // Stage handler key (GMX_V2, HYPERLIQUID, etc.)
    bytes32 positionKey; // Position being modified
    bytes32 action;      // Action type (stage-specific)
    bytes callOrder;     // Encoded call (target, calldata)
}

/// @title IStage
/// @notice Interface for stage handlers
/// @dev Implementations: GmxStage, HyperliquidStage, AaveStage, etc.
interface IStage {
    /// @notice Validate order before execution
    /// @param subaccount The subaccount executing
    /// @param token The collateral token
    /// @param order The order containing positionKey, action, callOrder
    /// @return hookData Data for processPostOrder() after execution
    function processOrder(address subaccount, IERC20 token, Order calldata order)
        external
        view
        returns (bytes memory hookData);

    /// @notice Validate order after execution
    /// @param subaccount The subaccount that executed
    /// @param token The collateral token
    /// @param order The order that was executed
    /// @param preBalance Token balance before execution
    /// @param postBalance Token balance after execution
    /// @param hookData Data returned from processOrder
    function processPostOrder(
        address subaccount,
        IERC20 token,
        Order calldata order,
        uint preBalance,
        uint postBalance,
        bytes calldata hookData
    ) external view;

    /// @notice Settle after execution (update position tracking)
    /// @param subaccount The subaccount that executed
    /// @param order The order that was executed
    /// @param hookData Data returned from processOrder
    function settle(address subaccount, Order calldata order, bytes calldata hookData) external;

    /// @notice Get current value of a position
    /// @param positionKey The position identifier
    /// @return value Net value in collateral token units
    function getValue(bytes32 positionKey) external view returns (uint value);
}
