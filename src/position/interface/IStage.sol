// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {CallType} from "modulekit/accounts/common/lib/ModeLib.sol";

/// @notice Single call in a batch (matches extension output and ERC-7579 Execution)
struct Call {
    address target;
    uint256 value;
    bytes data;
}

/// @title IStage
/// @notice Interface for stage handlers (GMX, Hyperliquid, etc.)
interface IStage {
    /// @notice Validate execution before it runs
    /// @param master The master account that controls the subaccount
    /// @param subaccount The subaccount executing
    /// @param value The ETH value sent with the execute() call
    /// @param callType The ERC-7579 call type (single or batch)
    /// @param execData The raw execution calldata
    /// @return token The collateral token extracted from execution data (address(0) if N/A)
    /// @return hookData Data for postCheck after execution
    function validate(
        address master,
        address subaccount,
        uint value,
        CallType callType,
        bytes calldata execData
    ) external view returns (IERC20 token, bytes memory hookData);

    /// @notice Verify state after execution
    /// @param subaccount The subaccount that executed
    /// @param token The collateral token
    /// @param preBalance Token balance before execution
    /// @param postBalance Token balance after execution
    /// @param hookData Data from validate()
    function verify(address subaccount, IERC20 token, uint preBalance, uint postBalance, bytes calldata hookData)
        external
        view;

    /// @notice Record position outcome after execution
    /// @param subaccount The subaccount that executed
    /// @param hookData Data from validate()
    function settle(address subaccount, bytes calldata hookData) external;

    /// @notice Get position value in base token units
    /// @param positionKey The position identifier
    /// @param baseToken The token to denominate value in
    /// @return Position value as base token amount
    function getPositionValue(bytes32 positionKey, IERC20 baseToken) external view returns (uint);

    /// @notice Verify a position belongs to a subaccount
    /// @param positionKey The position identifier
    /// @param subaccount The account to verify ownership
    /// @return isOwner True if position belongs to subaccount
    function verifyPositionOwner(bytes32 positionKey, address subaccount) external view returns (bool isOwner);

    /// @notice Check if an order is still pending
    /// @param orderKey The order identifier
    /// @param subaccount The account that created the order
    /// @return isPending True if order exists and is pending
    function isOrderPending(bytes32 orderKey, address subaccount) external view returns (bool isPending);
}
