// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import {BankStore} from "./../utils/BankStore.sol";
import {IAuthority} from "./../utils/interfaces/IAuthority.sol";
import {TokenRouter} from "./TokenRouter.sol";

/**
 * @title AllocationStore
 * @notice Minimal token storage contract focused only on token transfers
 * @dev User balance logic moved to Allocate.sol for better separation of concerns
 */
contract AllocationStore is BankStore {
    constructor(IAuthority _authority, TokenRouter _router) BankStore(_authority, _router) {}
}
