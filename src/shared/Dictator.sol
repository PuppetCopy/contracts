// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IAuthority} from "./../utils/interfaces/IAuthority.sol";

import {Auth} from "./../utils/access/Auth.sol";
import {Permission} from "./../utils/access/Permission.sol";

contract Dictator is Ownable, IAuthority {
    event UpdateAccess(address target, bool enabled);
    event UpdatePermission(address target, bytes4 functionSig, bool enabled);

    function hasAccess(Auth target, address user) external view returns (bool) {
        return target.canCall(user);
    }

    function hasPermission(Permission target, address user, bytes4 functionSig) external view returns (bool) {
        return target.canCall(user, functionSig);
    }

    constructor(address _owner) Ownable(_owner) {}

    function setAccess(Auth target, address user) public virtual onlyOwner {
        target.setAuth(user);

        emit UpdateAccess(user, true);
    }

    function removeAccess(Auth target, address user) public virtual onlyOwner {
        target.removeAuth(user);

        emit UpdateAccess(user, false);
    }

    function setPermission(Permission target, address user, bytes4 functionSig) public virtual onlyOwner {
        target.setPermission(user, functionSig);

        emit UpdatePermission(user, functionSig, true);
    }

    function removePermission(Permission target, address user, bytes4 functionSig) public virtual onlyOwner {
        target.removePermission(user, functionSig);

        emit UpdatePermission(user, functionSig, false);
    }
}
