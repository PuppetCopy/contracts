// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {TokenRouter} from "./../../shared/TokenRouter.sol";
import {Subaccount} from "./../../shared/Subaccount.sol";
import {BankStore} from "./../../shared/store/BankStore.sol";
import {IAuthority} from "./../../utils/interfaces/IAuthority.sol";
import {GmxPositionUtils} from "./../utils/GmxPositionUtils.sol";

contract AllocationStore is BankStore {
    constructor(IAuthority _authority, TokenRouter _router) BankStore(_authority, _router) {}
}
