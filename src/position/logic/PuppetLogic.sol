// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IWNT} from "./../../utils/interfaces/IWNT.sol";

import {SubaccountFactory} from "./../../shared/SubaccountFactory.sol";
import {SubaccountStore} from "./../../shared/store/SubaccountStore.sol";

import {Router} from "./../../utils/Router.sol";
import {PositionUtils} from "../util/PositionUtils.sol";
import {PuppetStore} from "../store/PuppetStore.sol";

library PuppetLogic {
    event PuppetLogic__SetRule(bytes32 ruleKey, PuppetStore.Rule rule);
    event PuppetLogic__DepositWnt(address account, uint amount);
    event PuppetLogic__WithdrawWnt(address account, uint amount);

    struct CallSetRuleConfig {
        Router router;
        PuppetStore store;
        uint minExpiryDuration;
        uint minAllowanceRate;
        uint maxAllowanceRate;
    }

    struct CallCreateSubaccountConfig {
        SubaccountFactory factory;
        SubaccountStore store;
    }

    struct CallSetDepositWntConfig {
        IWNT wnt;
        PuppetStore store;
        address holdingAddress;
        uint gasLimit;
    }

    function createSubaccount(CallCreateSubaccountConfig memory callConfig, address account) internal {
        callConfig.factory.createSubaccount(callConfig.store, account);
    }

    function setRule(
        CallSetRuleConfig memory callConfig,
        address trader,
        address collateralToken,
        address puppet,
        PuppetStore.Rule calldata ruleParams
    ) internal {
        bytes32 ruleKey = PositionUtils.getRuleKey(collateralToken, puppet, trader);

        PuppetStore.Rule memory storedRule = callConfig.store.getRule(ruleKey);
        uint tokenAllowance = _validateTokenAllowance(callConfig, puppet, collateralToken);

        // callConfig.store.setTokenAllowanceActivity(PositionUtils.getAllownaceKey(collateralToken, puppet), tokenAllowance);

        PuppetStore.Rule memory rule = _setRule(callConfig, storedRule, ruleParams);

        callConfig.store.setRule(rule, ruleKey);

        emit PuppetLogic__SetRule(ruleKey, rule);
    }

    function setRuleList(
        CallSetRuleConfig memory callConfig,
        address[] calldata traderList,
        address[] calldata collateralTokenList,
        PuppetStore.Rule[] calldata ruleParams,
        address puppet
    ) internal {
        uint length = traderList.length;
        address[] memory verifyAllowanceTokenList = new address[](0);
        bytes32[] memory keyList = new bytes32[](length);

        for (uint i = 0; i < length; i++) {
            bytes32 key = PositionUtils.getRuleKey(collateralTokenList[i], puppet, traderList[i]);

            keyList[i] = key;
        }

        PuppetStore.Rule[] memory storedRuleList = callConfig.store.getRuleList(keyList);

        for (uint i = 0; i < length; i++) {
            bytes32 ruleKey = keyList[i];

            storedRuleList[i] = _setRule(callConfig, storedRuleList[i], ruleParams[i]);

            if (isArrayContains(verifyAllowanceTokenList, collateralTokenList[i])) {
                verifyAllowanceTokenList[verifyAllowanceTokenList.length] = collateralTokenList[i];
            }

            emit PuppetLogic__SetRule(ruleKey, storedRuleList[i]);
        }

        callConfig.store.setRuleList(storedRuleList, keyList);

        for (uint i = 0; i < verifyAllowanceTokenList.length; i++) {
            uint tokenAllowance = _validateTokenAllowance(callConfig, puppet, verifyAllowanceTokenList[i]);

            // callConfig.store.setTokenAllowanceActivity(PositionUtils.getAllownaceKey(collateralTokenList[i], puppet), tokenAllowance);
        }
    }

    function _setRule(
        CallSetRuleConfig memory callConfig, //
        PuppetStore.Rule memory storedRule,
        PuppetStore.Rule calldata ruleParams
    ) internal view returns (PuppetStore.Rule memory) {
        if (ruleParams.expiry == 0) {
            if (storedRule.expiry == 0) revert PuppetLogic__NotFound();

            storedRule.expiry = 0;

            return storedRule;
        }

        if (ruleParams.expiry < block.timestamp + callConfig.minExpiryDuration) {
            revert PuppetLogic__ExpiredDate();
        }

        if (ruleParams.allowanceRate < callConfig.minAllowanceRate || ruleParams.allowanceRate > callConfig.maxAllowanceRate) {
            revert PuppetLogic__InvalidAllowanceRate(callConfig.minAllowanceRate, callConfig.maxAllowanceRate);
        }

        storedRule.throttleActivity = ruleParams.throttleActivity;
        storedRule.allowanceRate = ruleParams.allowanceRate;
        storedRule.expiry = ruleParams.expiry;

        return storedRule;
    }

    function isArrayContains(address[] memory array, address value) public pure returns (bool) {
        for (uint i = 0; i < array.length; i++) {
            if (array[i] == value) {
                return true;
            }
        }

        return false;
    }

    function _validateTokenAllowance(
        CallSetRuleConfig memory callConfig, //
        address from,
        address collateralToken
    ) internal view returns (uint) {
        uint tokenAllowance = IERC20(collateralToken).allowance(from, address(callConfig.router));

        if (tokenAllowance > callConfig.store.getTokenAllowanceCap(collateralToken)) {
            revert PuppetLogic__NotAllowedCollateralTokenAmount();
        }

        return tokenAllowance;
    }

    error PuppetLogic__InvalidAllowanceRate(uint min, uint max);
    error PuppetLogic__ExpiredDate();
    error PuppetLogic__NoAllowance();
    error PuppetLogic__InsufficientAllowance();
    error PuppetLogic__InsufficientBalance();
    error PuppetLogic__NotFound();
    error PuppetLogic__NotAllowedCollateralTokenAmount();
}
