// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Permission} from "./auth/Permission.sol";
import {IAuthority} from "./interfaces/IAuthority.sol";

/// @title Abstract Core Contract Base
/// @notice Base contract for functional modules managed by the Dictatorship (Authority).
/// @dev Handles interaction with the central Authority for configuration and event logging.
///      Inherits Permission logic linked to the Authority.
abstract contract CoreContract is Permission {
    /// @notice The central authority (Dictatorship) managing this contract.
    // Inherited 'authority' variable assumed from Permission contract
    /// @param _authority The address of the Dictatorship contract.
    constructor(IAuthority _authority) Permission(_authority) {
    }

    /// @notice Entry point for the Authority to push configuration updates.
    /// @dev Requires caller to be the registered Authority. Delegates to internal _setConfig implementation.
    ///      Logs a "SetConfig" event via the Authority upon successful configuration.
    /// @param data ABI-encoded configuration data specific to the inheriting contract.
    function setConfig(
        bytes calldata data
    ) external onlyAuthority {
        _setConfig(data);
        _logEvent("SetConfig", data);
    }

    /// @notice Internal function to be implemented by inheriting contracts to handle configuration logic.
    /// @param data ABI-encoded configuration data.
    function _setConfig(
        bytes calldata data
    ) internal virtual {
        // Implement specific configuration logic in inheriting contracts
        // This function is intentionally left empty to be overridden
    }

    /// @notice Helper function to log events through the central Authority.
    /// @param method A descriptor for the action or event type (e.g., "Deposit", "RuleUpdated").
    /// @param data ABI-encoded data specific to the event.
    function _logEvent(string memory method, bytes memory data) internal {
        authority.logEvent(method, data);
    }
}
