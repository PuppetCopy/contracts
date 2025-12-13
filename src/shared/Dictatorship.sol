// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.31;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {Error} from "../utils/Error.sol";
import {CoreContract} from "../utils/CoreContract.sol";
import {Access} from "../utils/auth/Access.sol";
import {Permission} from "../utils/auth/Permission.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";

contract Dictatorship is Ownable, IAuthority {
    event PuppetEventLog(address indexed coreContract, string indexed method, bytes data);

    mapping(address => bool) public registeredContract;

    constructor(
        address _initialOwner
    ) Ownable(_initialOwner) {
        registeredContract[address(this)] = true;
    }

    function hasAccess(Access _target, address _user) external view returns (bool) {
        return _target.canCall(_user);
    }

    function hasPermission(Permission _target, bytes4 _functionSig, address _user) external view returns (bool) {
        return _target.canCall(_functionSig, _user);
    }

    function logEvent(string calldata _method, bytes calldata _data) external {
        if (!registeredContract[msg.sender]) revert Error.Dictatorship__ContractNotRegistered();
        emit PuppetEventLog(msg.sender, _method, _data);
    }

    function setAccess(Access _target, address _user) external onlyOwner {
        _target.setAccess(_user, true);
        emit PuppetEventLog(address(this), "UpdateAccess", abi.encode(_target, _user, true));
    }

    function removeAccess(Access _target, address _user) external onlyOwner {
        _target.setAccess(_user, false);
        emit PuppetEventLog(address(this), "UpdateAccess", abi.encode(_target, _user, false));
    }

    function setPermission(Permission _target, bytes4 _functionSig, address _user) external onlyOwner {
        _target.setPermission(_functionSig, _user, true);
        emit PuppetEventLog(address(this), "UpdatePermission", abi.encode(address(_target), _user, _functionSig, true));
    }

    function removePermission(Permission _target, bytes4 _functionSig, address _user) external onlyOwner {
        _target.setPermission(_functionSig, _user, false);
        emit PuppetEventLog(address(this), "UpdatePermission", abi.encode(address(_target), _user, _functionSig, false));
    }

    function registerContract(
        CoreContract _contract
    ) external onlyOwner {
        if (!_contract.supportsInterface(type(CoreContract).interfaceId)) {
            revert Error.Dictatorship__InvalidCoreContract();
        }
        address targetAddress = address(_contract);
        if (registeredContract[targetAddress]) revert Error.Dictatorship__ContractAlreadyInitialized();

        registeredContract[targetAddress] = true;
        emit PuppetEventLog(targetAddress, "RegisterContract", "");
    }

    function setConfig(CoreContract _contract, bytes calldata _config) external onlyOwner {
        if (!registeredContract[address(_contract)]) revert Error.Dictatorship__ContractNotRegistered();

        try _contract.setConfig(_config) {}
        catch (bytes memory reason) {
            if (reason.length == 0) revert Error.Dictatorship__ConfigurationUpdateFailed();
            assembly {
                revert(add(32, reason), mload(reason))
            }
        }

        emit PuppetEventLog(address(_contract), "SetConfig", _config);
    }

    function removeContract(
        CoreContract _contract
    ) external onlyOwner {
        address targetAddress = address(_contract);
        if (!registeredContract[targetAddress]) revert Error.Dictatorship__ContractNotRegistered();

        registeredContract[targetAddress] = false;
        emit PuppetEventLog(targetAddress, "RemoveContract", "");
    }
}
