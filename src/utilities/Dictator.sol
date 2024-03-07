// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import {RolesAuthority, Authority} from "@solmate/contracts/auth/authorities/RolesAuthority.sol";

contract Dictator is RolesAuthority {
    constructor(address _owner) RolesAuthority(_owner, Authority(address(0))) {}
}
