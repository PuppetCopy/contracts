// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {CallType} from "modulekit/accounts/common/lib/ModeLib.sol";
import {IERC7579Account} from "modulekit/accounts/common/interfaces/IERC7579Account.sol";
import {Action, MasterInfo} from "./ITypes.sol";

/// @notice Single call in a batch (matches extension output and ERC-7579 Execution)
struct Call {
    address target;
    uint256 value;
    bytes data;
}

/// @title IStage
/// @notice Interface for stage handlers (GMX, Hyperliquid, etc.)
interface IStage {
    /// @notice Parse and validate execution, returning the action
    /// @param caller The address that called the master account's execute function
    /// @param master The master's 7579 account executing
    /// @param baseToken The master's base token for validation
    /// @param callValue The ETH value sent with the execute() call
    /// @param callType The ERC-7579 call type (single or batch)
    /// @param execData The raw execution calldata
    /// @return result Parsed action with selector and data
    function getAction(
        address caller,
        IERC7579Account master,
        IERC20 baseToken,
        uint callValue,
        CallType callType,
        bytes calldata execData
    ) external view returns (Action memory result);

    /// @notice Verify state after execution
    /// @param master The master account that executed
    /// @param token The collateral token
    /// @param preBalance Token balance before execution
    /// @param postBalance Token balance after execution
    /// @param hookData Data from validate()
    function verify(IERC7579Account master, IERC20 token, uint preBalance, uint postBalance, bytes calldata hookData)
        external
        view;

    /// @notice Get position value in base token units
    /// @param positionKey The position identifier
    /// @param baseToken The token to denominate value in
    /// @return Position value as base token amount
    function getPositionValue(bytes32 positionKey, IERC20 baseToken) external view returns (uint);

    /// @notice Verify a position belongs to a master account
    /// @param positionKey The position identifier
    /// @param master The account to verify ownership
    /// @return isOwner True if position belongs to master account
    function verifyPositionOwner(bytes32 positionKey, IERC7579Account master) external view returns (bool isOwner);

    /// @notice Check if an order is still pending
    /// @param orderKey The order identifier
    /// @param master The account that created the order
    /// @return isPending True if order exists and is pending
    function isOrderPending(bytes32 orderKey, IERC7579Account master) external view returns (bool isPending);
}
