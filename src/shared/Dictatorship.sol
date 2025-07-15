// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

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
    event PuppetEventLog(address indexed operator, string indexed method, bytes data);

    /// @notice Emitted when a CoreContract is initialized and added to the registry.
    event AddContractAccess(address indexed target);

    /// @notice Emitted when a CoreContract is removed from the registry.
    event RemoveContractAccess(address indexed target);

    // --- State ---

    /// @notice Mapping tracking registered CoreContracts allowed to log events.
    mapping(address => bool) public contractAccessRegistry;

    /// @notice Checks if a user has general access via the target Access contract.
    function hasAccess(Access _target, address _user) external view returns (bool) {
        return _target.canCall(_user);
    }

    /// @notice Checks if a user has specific function permission via the target Permission contract.
    function hasPermission(Permission _target, bytes4 _functionSig, address user) external view returns (bool) {
        return _target.canCall(_functionSig, user);
    }

    /// @param _initialOwner The address of the Governance contract that will own this Dictatorship.
    constructor(
        address _initialOwner
    ) Ownable(_initialOwner) {}

    /// @notice Grants general access to a user on a target Access contract.
    /// @param _target The Access contract instance to modify.
    /// @param _user The user address to grant access to.
    function setAccess(Access _target, address _user) public onlyOwner {
        require(_user != address(0), Error.Dictatorship__InvalidUserAddress());

        _target.setAccess(_user, true);
        emit UpdateAccess(address(_target), _user, true);
    }

    /// @notice Revokes general access from a user on a target Access contract.
    /// @param _target The Access contract instance to modify.
    /// @param _user The user address to revoke access from.
    function removeAccess(Access _target, address _user) public onlyOwner {
        _target.setAccess(_user, false);
        emit UpdateAccess(address(_target), _user, false);
    }

    /// @notice Grants function-specific permission to a user on a target Permission contract.
    /// @param _target The Permission contract instance to modify.
    /// @param _functionSig The function selector to grant permission for.
    /// @param _user The user address to grant permission to.
    function setPermission(Permission _target, bytes4 _functionSig, address _user) public onlyOwner {
        require(_user != address(0), Error.Dictatorship__InvalidUserAddress());
        require(_functionSig != bytes4(0), Error.Permission__InvalidFunctionSignature());
        require(
            IERC165(address(_target)).supportsInterface(type(CoreContract).interfaceId),
            Error.Dictatorship__InvalidCoreContract()
        );

        _target.setPermission(_functionSig, _user, true);
        emit UpdatePermission(address(_target), _user, _functionSig, true);
    }

    /// @notice Revokes function-specific permission from a user on a target Permission contract.
    /// @param _target The Permission contract instance to modify.
    /// @param _functionSig The function selector to revoke permission for.
    /// @param _user The user address to revoke permission from.
    function removePermission(Permission _target, bytes4 _functionSig, address _user) public onlyOwner {
        _target.setPermission(_functionSig, _user, false);
        emit UpdatePermission(address(_target), _user, _functionSig, false);
    }

    /// @notice Called by registered CoreContracts to log events centrally.
    /// @inheritdoc IAuthority
    function logEvent(string memory _method, bytes memory _data) public {
        require(contractAccessRegistry[msg.sender], Error.Dictatorship__ContractNotRegistered());
        emit PuppetEventLog(msg.sender, _method, _data);
    }

    /// @notice Initializes a CoreContract, registers it, and optionally sets initial configuration.
    /// @param _target The CoreContract instance to initialize.
    function initContract(
        CoreContract _target
    ) public onlyOwner {
        require(address(_target) != address(0), Error.Dictatorship__InvalidTargetAddress());

        address targetAddress = address(_target);
        require(!contractAccessRegistry[targetAddress], Error.Dictatorship__ContractAlreadyInitialized());

        contractAccessRegistry[targetAddress] = true;
        emit AddContractAccess(targetAddress);

        (bool success, bytes memory _data) = targetAddress.call(abi.encodeWithSignature("config()"));

        require(success, Error.Dictatorship__CoreContractConfigCallFailed());

        // Only set config if there is initial configuration
        if (_data.length > 0) {
            _setConfig(_target, _data);
        }
    }

    /// @notice Pushes a configuration update to a registered CoreContract.
    /// @param _target The CoreContract instance to configure.
    /// @param _config The ABI-encoded configuration data.
    function setConfig(CoreContract _target, bytes calldata _config) public onlyOwner {
        require(address(_target) != address(0), Error.Dictatorship__InvalidTargetAddress());
        require(_config.length > 0, Error.Dictatorship__EmptyConfiguration());
        require(
            IERC165(address(_target)).supportsInterface(type(CoreContract).interfaceId),
            Error.Dictatorship__InvalidCoreContract()
        );

        _setConfig(_target, _config);
    }

    /// @notice De-registers a CoreContract, preventing it from logging further events.
    /// @param _target The CoreContract instance to remove.
    function removeContract(
        CoreContract _target
    ) public onlyOwner {
        require(address(_target) != address(0), Error.Dictatorship__InvalidTargetAddress());

        address targetAddress = address(_target);
        require(contractAccessRegistry[targetAddress], Error.Dictatorship__ContractNotRegistered());

        contractAccessRegistry[targetAddress] = false;
        emit RemoveContractAccess(targetAddress);
    }

    /// @notice Internal function to set configuration on a CoreContract.
    /// @param _target The CoreContract instance to configure.
    /// @param _config The ABI-encoded configuration data.
    function _setConfig(CoreContract _target, bytes memory _config) internal {
        require(_config.length > 0, Error.Dictatorship__CoreContractInitConfigNotSet());

        // Add try-catch for config validation
        try _target.setConfig(_config) {}
        catch {
            revert Error.Dictatorship__ConfigurationUpdateFailed();
        }
    }
}
