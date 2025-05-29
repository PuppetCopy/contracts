// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import {Error} from "../utils/Error.sol";
import {Permission} from "./auth/Permission.sol";
import {IAuthority} from "./interfaces/IAuthority.sol";

/// @title Abstract Core Contract Base
/// @notice Base contract for functional modules managed by the Dictatorship (Authority).
/// @dev Handles interaction with the central Authority for configuration and event logging.
///      Inherits Permission logic linked to the Authority.
abstract contract CoreContract is Permission {
    bytes initConfig_; // Holds the current configuration of the contract

    function getInitConfig() external view returns (bytes memory) {
        return initConfig_;
    }

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

    function _setInitConfig(
        bytes memory _initConfig
    ) internal returns (bytes memory) {
        if (initConfig_.length != 0) {
            revert Error.CoreContract__ConfigurationNotSet();
        }

        initConfig_ = _initConfig;

        return initConfig_;
    }

    /// @notice Helper function to log events through the central Authority.
    /// @param method A descriptor for the action or event type (e.g., "Deposit", "RuleUpdated").
    /// @param data ABI-encoded data specific to the event.
    function _logEvent(string memory method, bytes memory data) internal {
        authority.logEvent(method, data);
    }
}
