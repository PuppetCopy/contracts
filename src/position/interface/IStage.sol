// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

/// @title IStage
/// @notice Interface for stage handlers
/// @dev Implementations: GmxStage, HyperliquidStage, AaveStage, etc.
interface IStage {
    /// @notice Validate opening a position
    /// @param subaccount The subaccount executing
    /// @param data Stage-specific encoded parameters
    /// @return positionKey The position being opened/added to
    /// @return hookData Data for settle() after execution
    function open(address subaccount, bytes calldata data)
        external
        view
        returns (bytes32 positionKey, bytes memory hookData);

    /// @notice Validate closing a position
    /// @param subaccount The subaccount executing
    /// @param data Stage-specific encoded parameters
    /// @return positionKey The position being closed/reduced
    /// @return hookData Data for settle() after execution
    function close(address subaccount, bytes calldata data)
        external
        view
        returns (bytes32 positionKey, bytes memory hookData);

    /// @notice Settle after execution (update position tracking)
    /// @param subaccount The subaccount that executed
    /// @param positionKey The position affected
    /// @param hookData Data returned from open/close
    function settle(address subaccount, bytes32 positionKey, bytes calldata hookData) external;

    /// @notice Get current value of a position
    /// @param positionKey The position identifier
    /// @return value Net value in collateral token units
    function getValue(bytes32 positionKey) external view returns (uint value);
}
