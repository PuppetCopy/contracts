// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";

abstract contract StoreController is Auth {
    address public setter;

    modifier isSetter() {
        if (setter != msg.sender) revert Unauthorized(setter, msg.sender);
        _;
    }

    constructor(Authority _authority, address _setter) Auth(address(0), _authority) {
        setter = _setter;

        emit AssignSetter(address(0), _setter, block.timestamp);
    }

    function switchSetter(address nextSetter) external requiresAuth {
        address oldSetter = setter;
        setter = nextSetter;

        emit AssignSetter(oldSetter, nextSetter, block.timestamp);
    }

    event AssignSetter(address from, address to, uint timestamp);

    error Unauthorized(address currentSetter, address sender);
}
