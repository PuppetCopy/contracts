// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import {Error} from "./../../shared/Error.sol";
import {IAccess} from "./../interfaces/IAccess.sol";
import {IAuthority} from "./../interfaces/IAuthority.sol";

abstract contract Access is IAccess {
    IAuthority public immutable authority;

    mapping(address => bool) internal authMap;

    function canCall(
        address user
    ) public view returns (bool) {
        return authMap[user];
    }

    constructor(
        IAuthority _authority
    ) {
        authority = _authority;
    }

    modifier auth() {
        if (canCall(msg.sender)) {
            _;
        } else {
            revert Error.Access__Unauthorized();
        }
    }

    modifier onlyAuthority() {
        if (msg.sender == address(authority)) {
            _;
        } else {
            revert Error.Access__Unauthorized();
        }
    }

    function setAccess(address user, bool isEnabled) external onlyAuthority {
        authMap[user] = isEnabled;
    }
}
