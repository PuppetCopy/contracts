// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {Error} from "../utils/Error.sol";
import {CoreContract} from "./../utils/CoreContract.sol";
import {Access} from "./../utils/auth/Access.sol";
import {Permission} from "./../utils/auth/Permission.sol";
import {IAuthority} from "./../utils/interfaces/IAuthority.sol";

/**
 * @notice Central authority for managing CoreContract permissions, configuration, and event logging
 * @dev Ownership should be held by a secure Governance contract
 */
contract Dictatorship is Ownable, IAuthority {
    /**
     * @notice Central log for events emitted by registered CoreContracts
     */
    event PuppetEventLog(address indexed operator, string indexed method, bytes data);

    mapping(address => bool) public registeredContract;

    uint public targetCallGasLimit = 500_000;

    /**
     * @notice Update gas limit for external calls
     */
    function settargetCallGasLimit(
        uint _gasLimit
    ) external onlyOwner {
        require(_gasLimit > 0, Error.Dictatorship__InvalidTargetAddress()); // Reuse existing error
        targetCallGasLimit = _gasLimit;
        emit PuppetEventLog(address(this), "SettargetCallGasLimit", abi.encode(_gasLimit));
    }

    /**
     * @notice Check if user has general access via target Access contract
     */
    function hasAccess(Access _target, address _user) external view returns (bool) {
        return _target.canCall(_user);
    }

    /**
     * @notice Check if user has specific function permission
     */
    function hasPermission(Permission _target, bytes4 _functionSig, address user) external view returns (bool) {
        return _target.canCall(_functionSig, user);
    }

    constructor(
        address _initialOwner
    ) Ownable(_initialOwner) {
        registeredContract[address(this)] = true; // Register self to allow event logging
    }

    /**
     * @notice Log events from registered CoreContracts
     */
    function logEvent(string memory _method, bytes memory _data) public {
        require(registeredContract[msg.sender], Error.Dictatorship__ContractNotRegistered());
        emit PuppetEventLog(msg.sender, _method, _data);
    }

    /**
     * @notice Grant general access to user on target Access contract
     */
    function setAccess(Access _target, address _user) public onlyOwner {
        _target.setAccess{gas: targetCallGasLimit}(_user, true);
        emit PuppetEventLog(address(this), "UpdateAccess", abi.encode(_target, _user, true));
    }

    /**
     * @notice Revoke general access from user on target Access contract
     */
    function removeAccess(Access _target, address _user) public onlyOwner {
        _target.setAccess{gas: targetCallGasLimit}(_user, false);
        emit PuppetEventLog(address(this), "UpdateAccess", abi.encode(_target, _user, false));
    }

    /**
     * @notice Grant function-specific permission to user
     */
    function setPermission(Permission _target, bytes4 _functionSig, address _user) public onlyOwner {
        _target.setPermission{gas: targetCallGasLimit}(_functionSig, _user, true);
        emit PuppetEventLog(address(this), "UpdatePermission", abi.encode(address(_target), _user, _functionSig, true));
    }

    /**
     * @notice Revoke function-specific permission from user
     */
    function removePermission(Permission _target, bytes4 _functionSig, address _user) public onlyOwner {
        _target.setPermission{gas: targetCallGasLimit}(_functionSig, _user, false);
        emit PuppetEventLog(address(this), "UpdatePermission", abi.encode(address(_target), _user, _functionSig, false));
    }

    /**
     * @notice Register a CoreContract for event logging
     */
    function registerContract(
        CoreContract _target
    ) public onlyOwner {
        address targetAddress = address(_target);
        require(!registeredContract[targetAddress], Error.Dictatorship__ContractAlreadyInitialized());

        registeredContract[targetAddress] = true;
        emit PuppetEventLog(targetAddress, "RegisterContract", abi.encode(targetAddress));
    }

    /**
     * @notice Push configuration update to registered CoreContract
     */
    function setConfig(CoreContract _target, bytes calldata _config) public onlyOwner {
        require(registeredContract[address(_target)], Error.Dictatorship__ContractNotRegistered());
        try _target.setConfig{gas: targetCallGasLimit}(_config) {}
        catch {
            revert Error.Dictatorship__ConfigurationUpdateFailed();
        }

        emit PuppetEventLog(address(_target), "SetConfig", _config);
    }

    /**
     * @notice De-register a CoreContract from event logging
     */
    function removeContract(
        CoreContract _target
    ) public onlyOwner {
        address targetAddress = address(_target);
        require(registeredContract[targetAddress], Error.Dictatorship__ContractNotRegistered());

        registeredContract[targetAddress] = false;
        emit PuppetEventLog(targetAddress, "RemoveContractAccess", abi.encode(targetAddress));
    }
}
