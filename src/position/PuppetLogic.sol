// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";

import {PuppetStore} from "./store/PuppetStore.sol";

contract PuppetLogic is Auth {
    event PuppetLogic__UpdateRule(bytes32 ruleKey, PuppetStore.Rule rule);

    struct CallSetRuleParams {
        PuppetStore store;
        uint minExpiryDuration;
        uint minAllowanceRate;
        uint maxAllowanceRate;
    }

    constructor(Authority _authority) Auth(address(0), _authority) {}

    function setRule(CallSetRuleParams calldata callParams, PuppetStore.Rule calldata callRule, bytes32 routeKey) external requiresAuth {
        if (callRule.expiry < block.timestamp + callParams.minExpiryDuration) {
            revert PuppetLogic__ExpiredDate();
        }

        if (callRule.allowanceRate < callParams.minAllowanceRate || callRule.allowanceRate > callParams.maxAllowanceRate) {
            revert PuppetLogic__MinAllowanceRate(100);
        }

        if (callRule.allowance == 0) revert PuppetLogic__NoAllowance();

        PuppetStore.Rule memory rule = callParams.store.getRule(routeKey);

        rule.throttleActivity = callRule.throttleActivity;
        rule.allowance = callRule.allowance;
        rule.allowanceRate = callRule.allowanceRate;
        rule.expiry = callRule.expiry;

        callParams.store.setRule(rule, routeKey);

        emit PuppetLogic__UpdateRule(routeKey, rule);
    }

    function setRouteActivityList(PuppetStore store, bytes32 routeKey, address[] calldata addressList, PuppetStore.Activity[] calldata activity)
        external
        requiresAuth
    {
        if (addressList.length != activity.length) revert PuppetStore__AddressListLengthMismatch();

        store.setRuleActivityList(routeKey, addressList, activity);
    }

    error PuppetLogic__MinAllowanceRate(uint rate);
    error PuppetLogic__ExpiredDate();
    error PuppetLogic__NoAllowance();
    error PuppetStore__AddressListLengthMismatch();
}
