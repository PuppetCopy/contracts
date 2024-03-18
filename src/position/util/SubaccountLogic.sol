// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";

import {Subaccount} from "./Subaccount.sol";
import {SubaccountStore} from "./../store/SubaccountStore.sol";

contract SubaccountLogic is Auth {
    event SubaccountLogic__Deposit(address account, uint amount);
    event SubaccountLogic__Withdraw(address account, uint amount);

    event PositionLogic__CreateSubaccount(address account, address subaccount);

    constructor(Authority _authority) Auth(address(0), _authority) {}

    function createSubaccount(SubaccountStore store, address account) external requiresAuth {
        if (address(store.getSubaccount(account)) == account) revert SubaccountLogic__AlreadyExists();

        Subaccount subaccount = new Subaccount(store, account);
        store.setSubaccount(account, subaccount);

        emit PositionLogic__CreateSubaccount(account, address(subaccount));
    }

    // function execute(SubaccountStore store, address from, address ctr, bytes calldata data) external {
    //     Subaccount subaccount = store.getSubaccount(from);
    //     if (subaccount.account() != from) revert SubaccountLogic__NotAccountOwner();

    //     subaccount.execute(ctr, data);
    // }

    // function deposit(SubaccountStore store, address from) external payable {
    //     Subaccount subaccount = store.getSubaccount(from);
    //     subaccount.deposit{value: msg.value}();

    //     emit SubaccountLogic__Deposit(from, msg.value);
    // }

    // function withdraw(SubaccountStore store, address from, uint amount) external {
    //     Subaccount subaccount = store.getSubaccount(from);
    //     subaccount.withdraw(amount);

    //     emit SubaccountLogic__Withdraw(from, amount);
    // }

    error SubaccountLogic__AlreadyExists();
    error SubaccountLogic__NotAccountOwner();
}
