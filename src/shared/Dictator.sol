// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {Access} from "./../utils/auth/Access.sol";
import {Permission} from "./../utils/auth/Permission.sol";
import {IAuthority} from "./../utils/interfaces/IAuthority.sol";

contract Dictator is Ownable, IAuthority {
    event UpdateAccess(address target, bool enabled);
    event UpdatePermission(address target, bytes4 functionSig, bool enabled);

    function hasAccess(Access target, address user) external view returns (bool) {
        return target.canCall(user);
    }

    function hasPermission(Permission target, bytes4 functionSig, address user) external view returns (bool) {
        return target.canCall(functionSig, user);
    }

    constructor(address _owner) Ownable(_owner) {}

    function setAccess(Access target, address user) public virtual onlyOwner {
        target.set(user);

        emit UpdateAccess(user, true);
    }

    function removeAccess(Access target, address user) public virtual onlyOwner {
        target.remove(user);

        emit UpdateAccess(user, false);
    }

    function setPermission(Permission target, bytes4 functionSig, address user) public virtual onlyOwner {
        target.set(functionSig, user);

        emit UpdatePermission(user, functionSig, true);
    }

    function removePermission(Permission target, bytes4 functionSig, address user) public virtual onlyOwner {
        target.remove(functionSig, user);

        emit UpdatePermission(user, functionSig, false);
    }
}
