// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Router} from "./../../shared/Router.sol";
import {PositionUtils} from "../../position/utils/PositionUtils.sol";
import {PuppetStore} from "../store/PuppetStore.sol";

library PuppetLogic {
    event PuppetLogic__SetRule(bytes32 ruleKey, PuppetStore.Rule rule);
    event PuppetLogic__Deposit(IERC20 token, address user, uint amount);
    event PuppetLogic__Withdraw(IERC20 token, address user, uint amount);

    struct CallSetRuleConfig {
        Router router;
        uint minExpiryDuration;
        uint minAllowanceRate;
        uint maxAllowanceRate;
    }

    function deposit(PuppetStore store, IERC20 token, address user, uint amount) internal {
        if (amount == 0) revert PuppetLogic__InvalidAmount();

        store.increaseBalance(token, user, amount);

        emit PuppetLogic__Deposit(token, user, amount);
    }

    function withdraw(PuppetStore store, IERC20 token, address user, address receiver, uint amount) internal {
        if (amount == 0) revert PuppetLogic__InvalidAmount();

        uint balance = store.getBalance(token, user);
        if (amount > balance) revert PuppetLogic__InsufficientBalance();

        store.decreaseBalance(token, user, receiver, amount);

        emit PuppetLogic__Withdraw(token, user, amount);
    }

    function setRule(
        PuppetStore store,
        CallSetRuleConfig memory callConfig,
        IERC20 collateralToken,
        address puppet,
        address trader,
        PuppetStore.Rule calldata ruleParams
    ) internal {
        bytes32 ruleKey = PositionUtils.getRuleKey(collateralToken, puppet, trader);
        _validatePuppetTokenAllowance(store, collateralToken, puppet);

        PuppetStore.Rule memory storedRule = store.getRule(ruleKey);
        PuppetStore.Rule memory rule = _setRule(callConfig, storedRule, ruleParams);

        store.setRule(ruleKey, rule);

        emit PuppetLogic__SetRule(ruleKey, rule);
    }

    function setRuleList(
        PuppetStore store,
        CallSetRuleConfig memory callConfig,
        address puppet,
        address[] calldata traderList,
        IERC20[] calldata collateralTokenList,
        PuppetStore.Rule[] calldata ruleParams
    ) internal {
        IERC20[] memory verifyAllowanceTokenList = new IERC20[](0);
        uint length = traderList.length;
        bytes32[] memory keyList = new bytes32[](length);

        for (uint i = 0; i < length; i++) {
            keyList[i] = PositionUtils.getRuleKey(collateralTokenList[i], puppet, traderList[i]);
        }

        PuppetStore.Rule[] memory storedRuleList = store.getRuleList(keyList);

        for (uint i = 0; i < length; i++) {
            storedRuleList[i] = _setRule(callConfig, storedRuleList[i], ruleParams[i]);

            if (isArrayContains(verifyAllowanceTokenList, collateralTokenList[i])) {
                verifyAllowanceTokenList[verifyAllowanceTokenList.length] = collateralTokenList[i];
            }

            emit PuppetLogic__SetRule(keyList[i], storedRuleList[i]);
        }

        store.setRuleList(keyList, storedRuleList);

        _validatePuppetTokenAllowanceList(store, verifyAllowanceTokenList, puppet);
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

    function isArrayContains(IERC20[] memory array, IERC20 value) public pure returns (bool) {
        for (uint i = 0; i < array.length; i++) {
            if (array[i] == value) {
                return true;
            }
        }

        return false;
    }

    function _validatePuppetTokenAllowanceList(
        PuppetStore store, //
        IERC20[] memory tokenList,
        address puppet
    ) internal view {
        for (uint i = 0; i < tokenList.length; i++) {
            _validatePuppetTokenAllowance(store, tokenList[i], puppet);
        }
    }

    function _validatePuppetTokenAllowance(
        PuppetStore store, //
        IERC20 token,
        address puppet
    ) internal view returns (uint) {
        uint tokenAllowance = store.getBalance(token, puppet);
        uint allowanceCap = store.getTokenAllowanceCap(token);

        if (allowanceCap == 0) revert PuppetLogic__TokenNotAllowed();
        if (tokenAllowance > allowanceCap) revert PuppetLogic__AllowanceAboveLimit(allowanceCap);

        return tokenAllowance;
    }

    error PuppetLogic__InvalidAllowanceRate(uint min, uint max);
    error PuppetLogic__ExpiredDate();
    error PuppetLogic__NotFound();
    error PuppetLogic__TokenNotAllowed();
    error PuppetLogic__AllowanceAboveLimit(uint allowanceCap);
    error PuppetLogic__InvalidAmount();
    error PuppetLogic__InsufficientBalance();
}
