// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

import {Permission} from "./auth/Permission.sol";
import {IAuthority} from "./interfaces/IAuthority.sol";

/// @title Abstract Core Contract Base
/// @notice Base contract for functional modules managed by the Dictatorship (Authority).
/// @dev Handles interaction with the central Authority for configuration and event logging.
///      Inherits Permission logic linked to the Authority.
abstract contract CoreContract is Permission, ERC165 {
    /// @notice The central authority (Dictatorship) managing this contract.
    // Inherited 'authority' variable assumed from Permission contract
    /// @param _authority The address of the Dictatorship contract.
    constructor(
        IAuthority _authority
    ) Permission(_authority) {}

    /// @notice  Sets the configuration parameters via governance
    /// @param _data The encoded configuration data
    /// @dev Emits a SetConfig event upon successful execution
    function _setConfig(
        bytes memory _data
    ) internal virtual;

    function setConfig(
        bytes calldata _data
    ) external virtual onlyAuthority {
        _setConfig(_data);

        _logEvent("SetConfig", _data);
    }

    /// @notice Helper function to log events through the central Authority.
    /// @param method A descriptor for the action or event type (e.g., "Deposit", "RuleUpdated").
    /// @param data ABI-encoded data specific to the event.
    function _logEvent(string memory method, bytes memory data) internal {
        authority.logEvent(method, data);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC165) returns (bool) {
        return interfaceId == type(CoreContract).interfaceId;
    }
}
