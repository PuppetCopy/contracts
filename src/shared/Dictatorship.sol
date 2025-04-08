// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {Error} from "../utils/Error.sol";
import {CoreContract} from "./../utils/CoreContract.sol";
import {Access} from "./../utils/auth/Access.sol";
import {Permission} from "./../utils/auth/Permission.sol";
import {IAuthority} from "./../utils/interfaces/IAuthority.sol";

/// @title Dictatorship Authority Contract
/// @notice Central authority for managing CoreContract permissions, configuration, lifecycle, and unified event
/// logging.
/// @dev Orchestrates access control by interacting with dedicated Access/Permission contracts.
///      Manages initialization and configuration of CoreContracts. Provides a central event log.
///      Ownership should be held by a secure Governance contract.
contract Dictatorship is Ownable, IAuthority {
    /// @notice Emitted when general access for a user is updated on a target Access contract.
    event UpdateAccess(address indexed target, address indexed user, bool enabled);

    /// @notice Emitted when function-specific permission for a user is updated on a target Permission contract.
    event UpdatePermission(address indexed target, address indexed user, bytes4 indexed functionSig, bool enabled);

    /// @notice Emitted when a configuration is pushed to a target CoreContract.
    event SetConfig(address indexed target, bytes config);

    /// @notice Central log for events emitted by registered CoreContracts via this authority.
    event LogEvent(address indexed operator, string indexed method, bytes data);

    /// @notice Emitted when a CoreContract is initialized and added to the registry.
    event AddContractAccess(address indexed target);

    /// @notice Emitted when a CoreContract is removed from the registry.
    event RemoveContractAccess(address indexed target);

    // --- State ---

    /// @notice Mapping tracking registered CoreContracts allowed to log events.
    mapping(address => bool) public contractAccessRegistry;

    /// @notice Checks if a user has general access via the target Access contract.
    function hasAccess(Access target, address user) external view returns (bool) {
        return target.canCall(user);
    }

    /// @notice Checks if a user has specific function permission via the target Permission contract.
    function hasPermission(Permission target, bytes4 functionSig, address user) external view returns (bool) {
        return target.canCall(functionSig, user);
    }

    /// @param initialOwner The address of the Governance contract that will own this Dictatorship.
    constructor(
        address initialOwner
    ) Ownable(initialOwner) {}

    /// @notice Grants general access to a user on a target Access contract.
    /// @param target The Access contract instance to modify.
    /// @param user The user address to grant access to.
    function setAccess(Access target, address user) public onlyOwner {
        target.setAccess(user, true);
        emit UpdateAccess(address(target), user, true);
    }

    /// @notice Revokes general access from a user on a target Access contract.
    /// @param target The Access contract instance to modify.
    /// @param user The user address to revoke access from.
    function removeAccess(Access target, address user) public onlyOwner {
        target.setAccess(user, false);
        emit UpdateAccess(address(target), user, false);
    }

    /// @notice Grants function-specific permission to a user on a target Permission contract.
    /// @param target The Permission contract instance to modify.
    /// @param functionSig The function selector to grant permission for.
    /// @param user The user address to grant permission to.
    function setPermission(Permission target, bytes4 functionSig, address user) public onlyOwner {
        target.setPermission(functionSig, user, true);
        emit UpdatePermission(address(target), user, functionSig, true);
    }

    /// @notice Revokes function-specific permission from a user on a target Permission contract.
    /// @param target The Permission contract instance to modify.
    /// @param functionSig The function selector to revoke permission for.
    /// @param user The user address to revoke permission from.
    function removePermission(Permission target, bytes4 functionSig, address user) public onlyOwner {
        target.setPermission(functionSig, user, false);
        emit UpdatePermission(address(target), user, functionSig, false);
    }

    /// @notice Called by registered CoreContracts to log events centrally.
    /// @inheritdoc IAuthority
    function logEvent(string memory method, bytes memory data) external {
        require(contractAccessRegistry[msg.sender], Error.Dictatorship__ContractNotInitialized());
        emit LogEvent(msg.sender, method, data);
    }

    /// @notice Initializes a CoreContract, registers it, and optionally sets initial configuration.
    /// @param target The CoreContract instance to initialize.
    /// @param config The ABI-encoded initial configuration data (can be empty bytes `""`).
    function initContract(CoreContract target, bytes calldata config) public onlyOwner {
        address targetAddress = address(target);
        require(!contractAccessRegistry[targetAddress], Error.Dictatorship__ContractAlreadyInitialized());

        contractAccessRegistry[targetAddress] = true;
        emit AddContractAccess(targetAddress);

        if (config.length > 0) {
            _setConfig(target, config);
        }
    }

    /// @notice Pushes a configuration update to a registered CoreContract.
    /// @param target The CoreContract instance to configure.
    /// @param config The ABI-encoded configuration data.
    function setConfig(CoreContract target, bytes calldata config) public onlyOwner {
        _setConfig(target, config);
    }

    /// @notice De-registers a CoreContract, preventing it from logging further events.
    /// @param target The CoreContract instance to remove.
    function removeContract(
        CoreContract target
    ) public onlyOwner {
        address targetAddress = address(target);
        require(contractAccessRegistry[targetAddress], Error.Dictatorship__ContractNotInitialized());

        contractAccessRegistry[targetAddress] = false;
        emit RemoveContractAccess(targetAddress);
    }

    /// @dev Internal function to perform the setConfig call on the target contract.
    function _setConfig(CoreContract target, bytes calldata config) internal {
        address targetAddress = address(target);

        require(contractAccessRegistry[targetAddress], Error.Dictatorship__ContractNotInitialized());

        (bool success,) = targetAddress.call(abi.encodeWithSignature("setConfig(bytes)", config));
        require(success, Error.Dictatorship__ConfigurationUpdateFailed());

        emit SetConfig(targetAddress, config);
    }
}
