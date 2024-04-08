// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {SubaccountStore} from "./store/SubaccountStore.sol";
import {Subaccount} from "./Subaccount.sol";

contract SubaccountFactory is Auth, ReentrancyGuard {
    event PositionLogic__CreateSubaccount(address account, address subaccount);

    constructor(Authority _authority) Auth(address(0), _authority) {}

    function createSubaccount(SubaccountStore store, address account) external requiresAuth nonReentrant returns (Subaccount subaccount) {
        if (address(store.getSubaccount(account)) == account) revert SubaccountFactory__AlreadyExists();

        subaccount = new Subaccount(store, account);
        store.setSubaccount(account, subaccount);

        emit PositionLogic__CreateSubaccount(account, address(subaccount));
    }

    error SubaccountFactory__AlreadyExists();
}
