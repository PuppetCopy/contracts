// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import {Error} from "./../../shared/Error.sol";
import {IAuthority} from "./../interfaces/IAuthority.sol";
import {IPermission} from "./../interfaces/IPermission.sol";

abstract contract Permission is IPermission {
    IAuthority public immutable authority;

    mapping(bytes4 signatureHash => mapping(address => bool)) internal permissionMap;

    function canCall(bytes4 signatureHash, address user) public view returns (bool) {
        return permissionMap[signatureHash][user];
    }

    constructor(
        IAuthority _authority
    ) {
        authority = _authority;
    }

    modifier auth() {
        if (canCall(msg.sig, msg.sender)) {
            _;
        } else {
            revert Error.Permission__Unauthorized();
        }
    }

    modifier onlyAuthority() {
        if (msg.sender == address(authority)) {
            _;
        } else {
            revert Error.Permission__Unauthorized();
        }
    }

    function setPermission(bytes4 functionSig, address user, bool isEnabled) external onlyAuthority {
        permissionMap[functionSig][user] = isEnabled;
    }

}
