// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import {IAuthority} from "./../interfaces/IAuthority.sol";

abstract contract Permission {
    IAuthority public immutable authority;

    mapping(address => mapping(bytes4 signatureHash => bool)) public permissionMap;

    function canCall(address user, bytes4 signatureHash) public view returns (bool) {
        return permissionMap[user][signatureHash];
    }

    constructor(IAuthority _authority) {
        authority = _authority;
    }

    modifier auth() {
        if (canCall(msg.sender, msg.sig)) {
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

    function setPermission(address user, bytes4 functionSig) external checkAuthority {
        permissionMap[user][functionSig] = true;
    }

    function removePermission(address user, bytes4 functionSig) external checkAuthority {
        delete permissionMap[user][functionSig];
    }

    error Auth_Unauthorized();
}
