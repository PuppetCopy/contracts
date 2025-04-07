// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Error} from "./../../utils/Error.sol";
import {IAuthority} from "./../interfaces/IAuthority.sol";

/// @title Abstract Contract for Function-Level Permission Control
/// @notice Provides granular access control based on function signatures (`bytes4`).
/// @dev Managed by a central Authority (Dictatorship). Inheriting contracts use the 'auth' modifier.
abstract contract Permission {
    /// @notice The central Authority contract responsible for managing permissions.
    IAuthority public immutable authority;

    /// @dev Mapping storing permission state: function signature => user address => allowed (bool).
    mapping(bytes4 signatureHash => mapping(address => bool)) internal permissionMap;

    /// @notice Checks if a user has permission to call a specific function signature.
    /// @param signatureHash The 4-byte function selector (`msg.sig`).
    /// @param user The address to check (`msg.sender`).
    /// @return True if the user has permission for the function, false otherwise.
    function canCall(bytes4 signatureHash, address user) public view virtual returns (bool) {
        return permissionMap[signatureHash][user];
    }

    /// @param _authority The address of the central Authority (Dictatorship).
    constructor(
        IAuthority _authority
    ) {
        require(address(_authority) != address(0), "Permission: Zero authority address");
        authority = _authority;
    }

    /// @notice Modifier to restrict function execution to permitted users only.
    /// @dev Checks permission based on `msg.sig` and `msg.sender`. Reverts if not permitted.
    modifier auth() {
        require(canCall(msg.sig, msg.sender), Error.Permission__Unauthorized());
        _;
    }

    /// @notice Modifier to restrict access to the central Authority contract only.
    modifier onlyAuthority() {
        require(msg.sender == address(authority), Error.Permission__CallerNotAuthority());
        _;
    }

    /// @notice Grants or revokes permission for a specific function signature and user.
    /// @dev Can only be called by the central Authority. Does not emit an event (Authority does).
    /// @param functionSig The 4-byte function selector.
    /// @param user The address to modify permission for.
    /// @param isEnabled True to grant permission, false to revoke.
    function setPermission(bytes4 functionSig, address user, bool isEnabled) external virtual onlyAuthority {
        permissionMap[functionSig][user] = isEnabled;
    }
}
