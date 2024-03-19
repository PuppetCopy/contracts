// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Router} from "./../utils/Router.sol";

import {PuppetUtils} from "./util/PuppetUtils.sol";
import {PuppetStore} from "./store/PuppetStore.sol";

contract PuppetLogic is Auth {
    event PuppetLogic__SetRule(bytes32 routeKey, bytes32 ruleKey, PuppetStore.Rule rule);

    struct CallSetRuleConfig {
        Router router;
        PuppetStore store;
        uint minExpiryDuration;
        uint minAllowanceRate;
        uint maxAllowanceRate;
    }

    constructor(Authority _authority) Auth(address(0), _authority) {}

    function setRule(CallSetRuleConfig calldata callConfig, PuppetStore.Rule calldata ruleParams, address puppet) external requiresAuth {
        bytes32 routeKey = PuppetUtils.getRouteKey(ruleParams.trader, ruleParams.collateralToken);
        bytes32 ruleKey = PuppetUtils.getRuleKey(puppet, routeKey);

        if (ruleParams.expiry == 0) {
            _disableRule(callConfig.store, ruleKey);

            return;
        }

        if (ruleParams.expiry < block.timestamp + callConfig.minExpiryDuration) {
            revert PuppetLogic__ExpiredDate();
        }

        if (ruleParams.allowanceRate < callConfig.minAllowanceRate || ruleParams.allowanceRate > callConfig.maxAllowanceRate) {
            revert PuppetLogic__InvalidAllowanceRate(callConfig.minAllowanceRate, callConfig.maxAllowanceRate);
        }

        if (ruleParams.allowance == 0) revert PuppetLogic__NoAllowance();

        if (IERC20(ruleParams.collateralToken).allowance(puppet, address(callConfig.router)) < ruleParams.allowance) {
            revert PuppetLogic__InsufficientAllowance();
        }

        if (IERC20(ruleParams.collateralToken).balanceOf(puppet) < ruleParams.allowance) {
            revert PuppetLogic__InsufficientBalance();
        }

        PuppetStore.Rule memory rule = callConfig.store.getRule(ruleKey);

        rule.throttleActivity = ruleParams.throttleActivity;
        rule.allowance = ruleParams.allowance;
        rule.allowanceRate = ruleParams.allowanceRate;
        rule.expiry = ruleParams.expiry;

        callConfig.store.setRule(rule, ruleKey);

        emit PuppetLogic__SetRule(routeKey, ruleKey, rule);
    }

    function _disableRule(PuppetStore store, bytes32 ruleKey) internal {
        PuppetStore.Rule memory rule = store.getRule(ruleKey);

        if (rule.expiry == 0) revert PuppetLogic__NotFound();

        rule.expiry = 0;

        store.setRule(rule, ruleKey);
    }

    function setRouteActivityList(PuppetStore store, bytes32 routeKey, address[] calldata addressList, PuppetStore.Activity[] calldata activity)
        external
        requiresAuth
    {
        if (addressList.length != activity.length) revert PuppetStore__AddressListLengthMismatch();

        store.setRuleActivityList(routeKey, addressList, activity);
    }

    error PuppetLogic__InvalidAllowanceRate(uint min, uint max);
    error PuppetLogic__ExpiredDate();
    error PuppetLogic__NoAllowance();
    error PuppetStore__AddressListLengthMismatch();
    error PuppetLogic__InsufficientAllowance();
    error PuppetLogic__InsufficientBalance();
    error PuppetLogic__NotFound();
}
