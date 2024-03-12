// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {PuppetUtils} from "./../utils/PuppetUtils.sol";
import {Router} from "src/utils/Router.sol";
import {PuppetStore} from "../store/PuppetStore.sol";

library PuppetLogic {
    event PuppetLogic__UpdateDeposit(address from, address to, bool isIncrease, IERC20 token, uint amount);
    event PuppetLogic__UpdateRule(bytes32 key, address puppet, address trader, bytes32 routeKey, uint allowanceRate, uint expiry);

    function setRule(PuppetStore store, address puppet, PuppetStore.Rule calldata ruleParams) external {
        if (ruleParams.expiry < block.timestamp + 1 days) {
            revert PuppetLogic__InvalidExpiry();
        }

        if (ruleParams.allowanceRate < 100) {
            revert PuppetLogic__MinAllowanceRate(100);
        }

        PuppetStore.Rule memory pts = store.getRule(ruleParams.routeKey);

        bytes32 key = PuppetUtils.getRuleKey(puppet, ruleParams.trader, ruleParams.routeKey);

        pts.trader = ruleParams.trader;
        pts.routeKey = ruleParams.routeKey;
        pts.allowanceRate = ruleParams.allowanceRate;
        pts.expiry = ruleParams.expiry;

        store.setRule(pts, key);

        emit PuppetLogic__UpdateRule(
            key,
            puppet,
            ruleParams.trader,
            ruleParams.routeKey,
            ruleParams.allowanceRate,
            ruleParams.expiry
        );
    }

    function removeRule(PuppetStore store, address puppet, address trader, bytes32 routeKey) external {
        bytes32 key = PuppetUtils.getRuleKey(puppet, trader, routeKey);

        store.removeRule(key);

        emit PuppetLogic__UpdateRule(key, puppet, trader, routeKey, 0, 0);
    }

    function deposit(Router router, PuppetStore store, IERC20 token, address from, address to, uint amount) external {
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

    function withdraw(Router router, PuppetStore store, IERC20 token, address from, address to, uint amount) external {
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
