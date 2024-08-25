// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {EventEmitter} from "./../utils/EventEmitter.sol";
import {Auth} from "./../utils/access/Auth.sol";
import {Permission} from "./../utils/access/Permission.sol";
import {IAuthority} from "./../utils/interfaces/IAuthority.sol";

contract Dictator is Ownable, IAuthority {
    event UpdateAccess(address target, bool enabled);
    event UpdatePermission(address target, bytes4 functionSig, bool enabled);

    function hasAccess(Auth target, address user) external view returns (bool) {
        return target.canCall(user);
    }

    function hasPermission(Permission target, address user, bytes4 functionSig) external view returns (bool) {
        return target.canCall(user, functionSig);
    }

    EventEmitter eventEmitter;

    constructor(EventEmitter _eventEmitter, address _owner) Ownable(_owner) {
        eventEmitter = _eventEmitter;
    }

    function setAccess(Auth target, address user) public virtual onlyOwner {
        target.setAuth(user);

        eventEmitter.log("Dictator", "1", "setAccess()", abi.encode(target, user));
    }

    function removeAccess(Auth target, address user) public virtual onlyOwner {
        target.removeAuth(user);

        eventEmitter.log("Dictator", "1", "removeAccess()", abi.encode(target, user));
    }

    function setPermission(Permission target, address user, bytes4 functionSig) public virtual onlyOwner {
        target.setPermission(user, functionSig);

        eventEmitter.log("Dictator", "1", "setPermission()", abi.encode(target, user, functionSig));
    }

    function removePermission(Permission target, address user, bytes4 functionSig) public virtual onlyOwner {
        target.removePermission(user, functionSig);

        eventEmitter.log("Dictator", "1", "removePermission()", abi.encode(target, user, functionSig));
    }

    function _transferOwnership(address newOwner) internal virtual override {
        eventEmitter.log("Dictator", "1", "_transferOwnership()", abi.encode(newOwner));
        _transferOwnership(newOwner);
    }
}
