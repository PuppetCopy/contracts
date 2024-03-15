// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";

import {Router} from "../utils/Router.sol";
import {PuppetUtils} from "./util/PuppetUtils.sol";
import {PuppetStore} from "./store/PuppetStore.sol";

contract PuppetLogic is Auth {
    event PuppetLogic__UpdateDeposit(address from, address to, bool isIncrease, IERC20 token, uint amount);
    event PuppetLogic__UpdateRule(bytes32 ruleKey, address puppet, address trader, uint allowanceRate, uint throttle, uint expiry);

    struct CallSetRuleParams {
        PuppetStore store;
        uint minExpiryDuration;
        uint minAllowanceRate;
        uint maxAllowanceRate;
        address puppet;
    }

    constructor(Authority _authority) Auth(address(0), _authority) {}

    function setRule(CallSetRuleParams calldata callParams, PuppetStore.Rule calldata callRule) external requiresAuth {
        if (callRule.expiry < block.timestamp + callParams.minExpiryDuration) {
            revert PuppetLogic__InvalidExpiry();
        }

        if (callRule.allowanceRate < callParams.minAllowanceRate || callRule.allowanceRate > callParams.maxAllowanceRate) {
            revert PuppetLogic__MinAllowanceRate(100);
        }

        bytes32 key = PuppetUtils.getRuleKey(callParams.puppet, callRule.trader);
        PuppetStore.Rule memory pts = callParams.store.getRule(key);

        pts.trader = callRule.trader;
        pts.positionKey = callRule.positionKey;
        pts.throttleActivity = callRule.throttleActivity;
        pts.allowanceRate = callRule.allowanceRate;
        pts.expiry = callRule.expiry;

        callParams.store.setRule(pts, key);

        emit PuppetLogic__UpdateRule(key, callParams.puppet, callRule.trader, callRule.allowanceRate, callRule.throttleActivity, callRule.expiry);
    }

    function removeRule(PuppetStore store, address puppet, address trader) external requiresAuth {
        bytes32 key = PuppetUtils.getRuleKey(puppet, trader);

        store.removeRule(key);

        emit PuppetLogic__UpdateRule(key, puppet, trader, 0, 0, 0);
    }

    function deposit(Router router, PuppetStore store, IERC20 token, address from, address to, uint amount) external requiresAuth {
        if (amount == 0) {
            revert PuppetLogic__ZeroAmount();
        }

        PuppetStore.Account memory pa = store.getAccount(from);

        router.pluginTransfer(token, from, address(store), amount);
        unchecked {
            pa.deposit += amount;
        }
        store.setAccount(from, pa);

        emit PuppetLogic__UpdateDeposit(from, to, true, token, amount);
    }

    function withdraw(Router router, PuppetStore store, IERC20 token, address from, address to, uint amount) external requiresAuth {
        PuppetStore.Account memory pa = store.getAccount(from);

        if (amount > pa.deposit) {
            revert PuppetLogic__WithdrawExceedsDeposit();
        }

        router.pluginTransfer(token, address(store), to, amount);

        pa.deposit -= amount; // underflow check is guranteed above?
        store.setAccount(from, pa);

        emit PuppetLogic__UpdateDeposit(from, to, false, token, amount);
    }

    error PuppetLogic__MinAllowanceRate(uint rate);
    error PuppetLogic__ZeroAmount();
    error PuppetLogic__WithdrawExceedsDeposit();
    error PuppetLogic__InvalidExpiry();
}
