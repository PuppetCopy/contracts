// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {Error} from "../utils/Error.sol";
import {CoreContract} from "../utils/CoreContract.sol";
import {Access} from "../utils/auth/Access.sol";
import {Permission} from "../utils/auth/Permission.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {EventEmitter} from "./EventEmitter.sol";

contract Dictatorship is Ownable, IAuthority, EventEmitter {
    mapping(address => bool) public registeredContractMap;

    constructor(address _initialOwner) Ownable(_initialOwner) {
        registeredContractMap[address(this)] = true;
    }

    function hasAccess(Access _target, address _user) external view returns (bool) {
        return _target.canCall(_user);
    }

    function hasPermission(Permission _target, bytes4 _functionSig, address _user) external view returns (bool) {
        return _target.canCall(_functionSig, _user);
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

    function registerContract(address _contract) external onlyOwner {
        if (registeredContractMap[_contract]) revert Error.Dictatorship__ContractAlreadyInitialized();

        registeredContractMap[_contract] = true;
        emit PuppetEventLog(_contract, "RegisterContract", "");
    }

    function setConfig(CoreContract _contract, bytes calldata _config) external onlyOwner {
        if (!registeredContractMap[address(_contract)]) revert Error.Dictatorship__ContractNotRegistered();
        if (!_contract.supportsInterface(type(CoreContract).interfaceId)) {
            revert Error.Dictatorship__InvalidCoreContract();
        }

        try _contract.setConfig(_config) {}
        catch (bytes memory reason) {
            if (reason.length == 0) revert Error.Dictatorship__ConfigurationUpdateFailed();
            assembly {
                revert(add(32, reason), mload(reason))
            }
        }

        emit PuppetEventLog(address(_contract), "SetConfig", _config);
    }

    function removeContract(address _contract) external onlyOwner {
        if (!registeredContractMap[_contract]) revert Error.Dictatorship__ContractNotRegistered();

        registeredContractMap[_contract] = false;
        emit PuppetEventLog(_contract, "RemoveContract", "");
    }
}
