// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Error} from "./../../shared/Error.sol"; // Adjust path
import {IAuthority} from "./../interfaces/IAuthority.sol"; // Adjust path

/// @title Abstract Contract for General Role-Based Access Control
/// @notice Provides basic access control where users are either authorized or not.
/// @dev Managed by a central Authority (Dictatorship). Inheriting contracts use the 'auth' modifier.
abstract contract Access {
    /// @notice The central Authority responsible for managing access.
    IAuthority public immutable authority;

    /// @dev Mapping storing the authorization state for each user address.
    mapping(address => bool) internal authMap;

    /// @notice Checks if a user is authorized (has general access).
    /// @param user The address to check.
    /// @return True if the user is authorized, false otherwise.
    function canCall(
        address user
    ) public view virtual returns (bool) {
        return authMap[user];
    }

    /// @param _authority The address of the central Authority (Dictatorship).
    constructor(
        IAuthority _authority
    ) {
        require(address(_authority) != address(0), "Access: Zero authority address");
        authority = _authority;
    }

    /// @notice Modifier to restrict access to authorized users only.
    /// @dev Reverts if `canCall(msg.sender)` returns false.
    modifier auth() {
        require(canCall(msg.sender), Error.Access__Unauthorized());
        _;
    }

    /// @notice Modifier to restrict access to the central Authority contract only.
    modifier onlyAuthority() {
        // "Access: Caller not authority"
        require(msg.sender == address(authority), Error.Access__CallerNotAuthority());
        _;
    }

    /// @notice Grants or revokes general access for a specific user.
    /// @dev Can only be called by the central Authority. Does not emit an event (Authority does).
    /// @param user The address to modify access for.
    /// @param isEnabled True to grant access, false to revoke.
    function setAccess(address user, bool isEnabled) external virtual onlyAuthority {
        authMap[user] = isEnabled;
    }
}
