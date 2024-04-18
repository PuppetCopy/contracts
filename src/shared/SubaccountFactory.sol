// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {SubaccountStore} from "./store/SubaccountStore.sol";
import {Subaccount} from "./Subaccount.sol";

contract SubaccountFactory is Auth, ReentrancyGuard {
    event PositionLogic__CreateSubaccount(address user, address subaccount);

    constructor(Authority _authority) Auth(address(0), _authority) {}

    function createSubaccount(SubaccountStore store, address user) external requiresAuth nonReentrant returns (Subaccount subaccount) {
        if (address(store.getSubaccount(user)) == user) revert SubaccountFactory__AlreadyExists();

        subaccount = new Subaccount(store, user);
        store.setSubaccount(user, subaccount);

        emit PositionLogic__CreateSubaccount(user, address(subaccount));
    }

    error SubaccountFactory__AlreadyExists();
}
