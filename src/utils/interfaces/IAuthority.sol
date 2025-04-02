// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

/// @title IAuthority Interface
/// @notice Defines the functions required by CoreContracts from the central authority.
interface IAuthority {
    /// @notice Logs an event from a registered contract
    /// @param method The method name to log
    /// @param data Additional data to log with the event
    function logEvent(string memory method, bytes memory data) external;
}
