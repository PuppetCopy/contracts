// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";

import {Router} from "../utils/Router.sol";

import {PuppetStore} from "./store/PuppetStore.sol";
import {PuppetLogic} from "./logic/PuppetLogic.sol";

contract Puppet is Auth {
    constructor(Authority _authority) Auth(address(0), _authority) {}

    function setRule(PuppetStore store, address puppet, PuppetStore.Rule calldata ruleParams) external requiresAuth {
        PuppetLogic.setRule(store, puppet, ruleParams);
    }

    function removeRule(PuppetStore store, address puppet, address trader, bytes32 routeKey) external requiresAuth {
        PuppetLogic.removeRule(store, puppet, trader, routeKey);
    }

    function deposit(Router router, PuppetStore store, IERC20 token, address from, address to, uint amount) external requiresAuth {
        PuppetLogic.deposit(router, store, token, from, to, amount);
    }

    function withdraw(Router router, PuppetStore store, IERC20 token, address from, address to, uint amount) external requiresAuth {
        PuppetLogic.withdraw(router, store, token, from, to, amount);
    }
}
