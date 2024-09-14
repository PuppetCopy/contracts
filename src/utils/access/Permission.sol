// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import {IAuthority} from "./../interfaces/IAuthority.sol";

abstract contract Permission {
    IAuthority public immutable authority;

    mapping(bytes4 signatureHash => mapping(address => bool)) internal permissionMap;

    function canCall(bytes4 signatureHash, address user) public view returns (bool) {
        return permissionMap[signatureHash][user];
    }

    constructor(IAuthority _authority) {
        authority = _authority;
    }

    modifier auth() {
        if (canCall(msg.sig, msg.sender)) {
            _;
        } else {
            revert Auth_Unauthorized();
        }
    }

    modifier checkAuthority() {
        if (msg.sender == address(authority)) {
            _;
        } else {
            revert Auth_Unauthorized();
        }
    }

    function setPermission(bytes4 functionSig, address user) external checkAuthority {
        permissionMap[functionSig][user] = true;
    }

    function removePermission(bytes4 functionSig, address user) external checkAuthority {
        delete permissionMap[functionSig][user];
    }

    error Auth_Unauthorized();
}
