// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";

import {Router} from "../utilities/Router.sol";

import {PuppetStore} from "./store/PuppetStore.sol";
import {PuppetLogic} from "./logic/PuppetLogic.sol";

contract Puppet is Auth {
    constructor(Authority _authority) Auth(address(0), _authority) {}

    function subscribe(PuppetStore store, address puppet, PuppetStore.PuppetTraderSubscription calldata subscriptionParams) external requiresAuth {
        PuppetLogic.subscribe(store, puppet, subscriptionParams);
    }

    function removeSubscription(PuppetStore store, address puppet, address trader, bytes32 routeKey) external requiresAuth {
        PuppetLogic.removeSubscription(store, puppet, trader, routeKey);
    }

    function deposit(Router router, PuppetStore store, IERC20 token, address from, address to, uint amount) external requiresAuth {
        PuppetLogic.deposit(router, store, token, from, to, amount);
    }

    function withdraw(Router router, PuppetStore store, IERC20 token, address from, address to, uint amount) external requiresAuth {
        PuppetLogic.withdraw(router, store, token, from, to, amount);
    }
}
