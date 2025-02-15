// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

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
        require(canCall(msg.sender), Error.Access__Unauthorized());

        _;
    }

    modifier onlyAuthority() {
        require(msg.sender == address(authority), Error.Access__Unauthorized());

        _;
    }

    function setAccess(address user, bool isEnabled) external onlyAuthority {
        authMap[user] = isEnabled;
    }
}
