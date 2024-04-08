// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {BankStore} from "./BankStore.sol";
import {Router} from "./Router.sol";

// @title StrictBankStore
// @dev Contract to record token transfers and sync token balances in the contract, this is a strict version of Bank
abstract contract StrictBankStore is BankStore {
    constructor(Authority _authority, Router _router, address _initSetter) BankStore(_authority, _router, _initSetter) {}
    // @dev records a token transfer into the contractBankStore
    // @param token the token to record the transfer for
    // @return the amount of tokens transferred in
    function recordTransferIn(IERC20 token) external requiresAuth returns (uint) {
        uint prevBalance = tokenBalanceMap[token];
        uint nextBalance = token.balanceOf(address(this));
        tokenBalanceMap[token] = nextBalance;

        return nextBalance - prevBalance;
    }

    // @dev this can be used to update the tokenBalances in case of token burns
    // or similar balance changes
    // the prevBalance is not validated to be more than the nextBalance as this
    // could allow someone to block this call by transferring into the contract
    // @param token the token to record the burn for
    // @return the new balance
    function syncTokenBalance(IERC20 token) external requiresAuth returns (uint) {
        uint nextBalance = token.balanceOf(address(this));
        tokenBalanceMap[token] = nextBalance;
        return nextBalance;
    }
}
