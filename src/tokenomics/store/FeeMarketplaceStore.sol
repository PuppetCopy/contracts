// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {TokenRouter} from "./../../shared/TokenRouter.sol";
import {BankStore} from "./../../utils/BankStore.sol";
import {IAuthority} from "./../../utils/interfaces/IAuthority.sol";

contract FeeMarketplaceStore is BankStore {
    constructor(IAuthority _authority, TokenRouter _router) BankStore(_authority, _router) {}
}
