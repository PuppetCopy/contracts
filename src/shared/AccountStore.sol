// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.31;

import {BankStore} from "./../utils/BankStore.sol";
import {IAuthority} from "./../utils/interfaces/IAuthority.sol";

/**
 * @title AccountStore
 * @notice Minimal token storage contract focused only on token transfers
 * @dev User balance logic moved to Account.sol for better separation of concerns
 */
contract AccountStore is BankStore {
    constructor(IAuthority _authority) BankStore(_authority) {}
}
