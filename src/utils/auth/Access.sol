// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {TransientSlot} from "@openzeppelin/contracts/utils/TransientSlot.sol";
import {Error} from "./../../utils/Error.sol"; // Adjust path
import {IAuthority} from "./../interfaces/IAuthority.sol"; // Adjust path

/// @title Abstract Contract for General Role-Based Access Control
/// @notice Provides basic access control where users are either authorized or not.
/// @dev Managed by a central Authority (Dictatorship). Inheriting contracts use the 'auth' modifier.
abstract contract Access {
    // Reentrancy guard using transient storage - uses OpenZeppelin's standard slot
    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.ReentrancyGuard")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant REENTRANCY_GUARD_SLOT = 0x9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f00;
    
    error ReentrancyGuardReentrantCall();
    /// @notice The central Authority contract responsible for managing access.
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
        if (address(_authority) == address(0)) revert("Access: Zero authority address");
        authority = _authority;
    }

    /// @notice Modifier to restrict access to authorized users only.
    /// @dev Reverts if `canCall(msg.sender)` returns false. Includes reentrancy protection.
    modifier auth() {
        _authBefore();
        _;
        _authAfter();
    }

    function _authBefore() internal {
        if (TransientSlot.tload(TransientSlot.asBoolean(REENTRANCY_GUARD_SLOT))) {
            revert ReentrancyGuardReentrantCall();
        }
        TransientSlot.tstore(TransientSlot.asBoolean(REENTRANCY_GUARD_SLOT), true);
        if (!canCall(msg.sender)) revert Error.Access__Unauthorized();
    }

    function _authAfter() internal {
        TransientSlot.tstore(TransientSlot.asBoolean(REENTRANCY_GUARD_SLOT), false);
    }

    /// @notice Modifier to restrict access to the central Authority contract only.
    modifier onlyAuthority() {
        _onlyAuthority();
        _;
    }

    function _onlyAuthority() internal view {
        if (msg.sender != address(authority)) revert Error.Access__CallerNotAuthority();
    }

    /// @notice Grants or revokes general access for a specific user.
    /// @dev Can only be called by the central Authority. Does not emit an event (Authority does).
    /// @param user The address to modify access for.
    /// @param isEnabled True to grant access, false to revoke.
    function setAccess(address user, bool isEnabled) external virtual onlyAuthority {
        authMap[user] = isEnabled;
    }
}
