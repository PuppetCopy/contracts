// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import {TransientSlot} from "@openzeppelin/contracts/utils/TransientSlot.sol";
import {Error} from "./../../utils/Error.sol";
import {IAuthority} from "./../interfaces/IAuthority.sol";

/// @title Abstract Contract for Function-Level Permission Control
/// @notice Provides granular access control based on function signatures (`bytes4`).
/// @dev Managed by a central Authority (Dictatorship). Inheriting contracts use the 'auth' modifier.
abstract contract Permission {
    // Reentrancy guard using transient storage - uses OpenZeppelin's standard slot
    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.ReentrancyGuard")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant REENTRANCY_GUARD_SLOT = 0x9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f00;
    
    error ReentrancyGuardReentrantCall();
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
    /// @dev Checks permission based on `msg.sig` and `msg.sender`. Includes reentrancy protection.
    modifier auth() {
        if (TransientSlot.tload(TransientSlot.asBoolean(REENTRANCY_GUARD_SLOT))) {
            revert ReentrancyGuardReentrantCall();
        }
        TransientSlot.tstore(TransientSlot.asBoolean(REENTRANCY_GUARD_SLOT), true);
        
        require(canCall(msg.sig, msg.sender), Error.Permission__Unauthorized());
        _;
        
        TransientSlot.tstore(TransientSlot.asBoolean(REENTRANCY_GUARD_SLOT), false);
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
