// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import {IAccess} from "./../interfaces/IAccess.sol";
import {IAuthority} from "./../interfaces/IAuthority.sol";

abstract contract Access is IAccess {
    IAuthority public immutable authority;

    mapping(address => bool) internal authMap;

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

    function set(address user) external checkAuthority {
        authMap[user] = true;
    }

    function remove(address user) external checkAuthority {
        authMap[user] = false;
    }

    error Auth_Unauthorized();
}
