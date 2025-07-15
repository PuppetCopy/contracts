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
    /// @notice Central log for events emitted by registered CoreContracts via this authority.
    event PuppetEventLog(address indexed operator, string indexed method, bytes data);

    /// @notice Mapping tracking registered CoreContracts allowed to log events.
    mapping(address => bool) public registeredContract;

    /// @notice Gas limit for external calls to prevent griefing attacks.
    uint public targetCallGasLimit = 500_000;

    /// @notice Updates the gas limit for external calls.
    /// @param _gasLimit The new gas limit.
    function settargetCallGasLimit(
        uint _gasLimit
    ) external onlyOwner {
        require(_gasLimit > 0, Error.Dictatorship__InvalidTargetAddress()); // Reuse existing error
        targetCallGasLimit = _gasLimit;
        emit PuppetEventLog(address(this), "SettargetCallGasLimit", abi.encode(_gasLimit));
    }

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
    ) Ownable(_initialOwner) {
        registeredContract[address(this)] = true; // Register self to allow event logging
    }

    /// @notice Called by registered CoreContracts to log events centrally.
    /// @inheritdoc IAuthority
    function logEvent(string memory _method, bytes memory _data) public {
        require(registeredContract[msg.sender], Error.Dictatorship__ContractNotRegistered());
        emit PuppetEventLog(msg.sender, _method, _data);
    }

    /// @notice Grants general access to a user on a target Access contract.
    /// @param _target The Access contract instance to modify.
    /// @param _user The user address to grant access to.
    function setAccess(Access _target, address _user) public onlyOwner {
        _target.setAccess{gas: targetCallGasLimit}(_user, true);
        emit PuppetEventLog(address(this), "UpdateAccess", abi.encode(_target, _user, true));
    }

    /// @notice Revokes general access from a user on a target Access contract.
    /// @param _target The Access contract instance to modify.
    /// @param _user The user address to revoke access from.
    function removeAccess(Access _target, address _user) public onlyOwner {
        _target.setAccess{gas: targetCallGasLimit}(_user, false);
        emit PuppetEventLog(address(this), "UpdateAccess", abi.encode(_target, _user, false));
    }

    /// @notice Grants function-specific permission to a user on a target Permission contract.
    /// @param _target The Permission contract instance to modify.
    /// @param _functionSig The function selector to grant permission for.
    /// @param _user The user address to grant permission to.
    function setPermission(Permission _target, bytes4 _functionSig, address _user) public onlyOwner {
        _target.setPermission{gas: targetCallGasLimit}(_functionSig, _user, true);
        emit PuppetEventLog(address(this), "UpdatePermission", abi.encode(address(_target), _user, _functionSig, true));
    }

    /// @notice Revokes function-specific permission from a user on a target Permission contract.
    /// @param _target The Permission contract instance to modify.
    /// @param _functionSig The function selector to revoke permission for.
    /// @param _user The user address to revoke permission from.
    function removePermission(Permission _target, bytes4 _functionSig, address _user) public onlyOwner {
        _target.setPermission{gas: targetCallGasLimit}(_functionSig, _user, false);
        emit PuppetEventLog(address(this), "UpdatePermission", abi.encode(address(_target), _user, _functionSig, false));
    }

    /// @notice Registers a CoreContract for event logging and logs its initial configuration.
    /// @param _target The CoreContract instance to register.
    function registerContract(
        CoreContract _target
    ) public onlyOwner {
        address targetAddress = address(_target);
        require(!registeredContract[targetAddress], Error.Dictatorship__ContractAlreadyInitialized());

        registeredContract[targetAddress] = true;
        emit PuppetEventLog(targetAddress, "RegisterContract", abi.encode(targetAddress));
    }

    /// @notice Pushes a configuration update to a registered CoreContract.
    /// @param _target The CoreContract instance to configure.
    /// @param _config The ABI-encoded configuration data.
    function setConfig(CoreContract _target, bytes calldata _config) public onlyOwner {
        require(registeredContract[address(_target)], Error.Dictatorship__ContractNotRegistered());
        try _target.setConfig{gas: targetCallGasLimit}(_config) {}
        catch {
            revert Error.Dictatorship__ConfigurationUpdateFailed();
        }

        emit PuppetEventLog(address(_target), "SetConfig", _config);
    }

    /// @notice De-registers a CoreContract, preventing it from logging further events.
    /// @param _target The CoreContract instance to remove.
    function removeContract(
        CoreContract _target
    ) public onlyOwner {
        address targetAddress = address(_target);
        require(registeredContract[targetAddress], Error.Dictatorship__ContractNotRegistered());

        registeredContract[targetAddress] = false;
        emit PuppetEventLog(targetAddress, "RemoveContractAccess", abi.encode(targetAddress));
    }
}
