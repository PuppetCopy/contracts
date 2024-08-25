// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import {IAuthority} from "./../interfaces/IAuthority.sol";

abstract contract Auth {
    IAuthority public immutable authority;

    mapping(address => bool) public authMap;

    function canCall(address user) public view returns (bool) {
        return authMap[user];
    }

    constructor(IAuthority _authority) {
        authority = _authority;
    }

    modifier auth() {
        if (canCall(msg.sender)) {
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

    function setAuth(address user) external checkAuthority {
        authMap[user] = true;
    }

    function removeAuth(address user) external checkAuthority {
        delete authMap[user];
    }

    error Auth_Unauthorized();
}
