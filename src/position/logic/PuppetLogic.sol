// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Router} from "./../../utils/Router.sol";
import {PositionUtils} from "../util/PositionUtils.sol";
import {PuppetStore} from "../store/PuppetStore.sol";

library PuppetLogic {
    event PuppetLogic__SetRule(bytes32 routeKey, bytes32 ruleKey, PuppetStore.Rule rule);

    struct CallSetRuleConfig {
        Router router;
        PuppetStore store;
        uint minExpiryDuration;
        uint minAllowanceRate;
        uint maxAllowanceRate;
    }

    function setRule(CallSetRuleConfig memory callConfig, PuppetStore.Rule calldata ruleParams, address puppet) internal {
        bytes32 routeKey = PositionUtils.getRouteKey(ruleParams.trader, ruleParams.collateralToken);
        bytes32 ruleKey = PositionUtils.getRuleKey(puppet, routeKey);

        PuppetStore.Rule memory rule = _setRule(callConfig, ruleParams, puppet, routeKey);

        callConfig.store.setRule(rule, ruleKey);

        emit PuppetLogic__SetRule(routeKey, ruleKey, rule);
    }

    function setRuleList(CallSetRuleConfig memory callConfig, PuppetStore.Rule[] calldata ruleParams, address[] calldata traderList, address puppet)
        internal
    {
        uint length = traderList.length;
        for (uint i = 0; i < length; i++) {
            bytes32 routeKey = PositionUtils.getRouteKey(traderList[i], ruleParams[i].collateralToken);
            bytes32 ruleKey = PositionUtils.getRuleKey(puppet, routeKey);

            PuppetStore.Rule memory rule = _setRule(callConfig, ruleParams[i], puppet, routeKey);

            callConfig.store.setRule(rule, ruleKey);

            emit PuppetLogic__SetRule(routeKey, ruleKey, rule);
        }
    }

    function _setRule(
        CallSetRuleConfig memory callConfig, //
        PuppetStore.Rule calldata ruleParams,
        address from,
        bytes32 routeKey
    ) internal view returns (PuppetStore.Rule memory) {
        bytes32 ruleKey = PositionUtils.getRuleKey(from, routeKey);
        PuppetStore.Rule memory rule = callConfig.store.getRule(ruleKey);

        if (ruleParams.expiry == 0) {
            if (rule.expiry == 0) revert PuppetLogic__NotFound();

            rule.expiry = 0;

            return rule;
        }

        if (ruleParams.expiry < block.timestamp + callConfig.minExpiryDuration) {
            revert PuppetLogic__ExpiredDate();
        }

        if (ruleParams.allowanceRate < callConfig.minAllowanceRate || ruleParams.allowanceRate > callConfig.maxAllowanceRate) {
            revert PuppetLogic__InvalidAllowanceRate(callConfig.minAllowanceRate, callConfig.maxAllowanceRate);
        }

        if (ruleParams.allowance == 0) revert PuppetLogic__NoAllowance();

        if (IERC20(ruleParams.collateralToken).allowance(from, address(callConfig.router)) < ruleParams.allowance) {
            revert PuppetLogic__InsufficientAllowance();
        }

        if (IERC20(ruleParams.collateralToken).balanceOf(from) < ruleParams.allowance) {
            revert PuppetLogic__InsufficientBalance();
        }

        rule.throttleActivity = ruleParams.throttleActivity;
        rule.allowance = ruleParams.allowance;
        rule.allowanceRate = ruleParams.allowanceRate;
        rule.expiry = ruleParams.expiry;

        return rule;
    }

    error PuppetLogic__InvalidAllowanceRate(uint min, uint max);
    error PuppetLogic__ExpiredDate();
    error PuppetLogic__NoAllowance();
    error PuppetLogic__InsufficientAllowance();
    error PuppetLogic__InsufficientBalance();
    error PuppetLogic__NotFound();
}
