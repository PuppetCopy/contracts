// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {SubaccountFactory} from "./../../shared/SubaccountFactory.sol";
import {SubaccountStore} from "./../../shared/store/SubaccountStore.sol";

import {Router} from "./../../utils/Router.sol";
import {PositionUtils} from "../util/PositionUtils.sol";
import {PuppetStore} from "../store/PuppetStore.sol";

library PuppetLogic {
    event PuppetLogic__SetRule(bytes32 ruleKey, PuppetStore.Rule rule);
    event PuppetLogic__Deposit(IERC20 token, address account, uint amount);
    event PuppetLogic__Withdraw(IERC20 token, address account, uint amount);

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

    struct CallSetBalanceConfig {
        Router router;
        PuppetStore store;
        address positionRouterAddress;
    }

    function createSubaccount(CallCreateSubaccountConfig memory callConfig, address account) internal {
        callConfig.factory.createSubaccount(callConfig.store, account);
    }

    function deposit(CallSetBalanceConfig memory callConfig, IERC20 token, address account, uint amount) internal {
        if (amount == 0) revert PuppetLogic__InvalidAmount();

        callConfig.router.transfer(token, msg.sender, callConfig.positionRouterAddress, amount);

        uint balance = callConfig.store.getBalance(token, account);
        callConfig.store.setBalance(token, account, balance + amount);

        emit PuppetLogic__Deposit(token, account, amount);
    }

    function withdraw(CallSetBalanceConfig memory callConfig, IERC20 token, address account, uint amount) internal {
        if (amount == 0) revert PuppetLogic__InvalidAmount();

        uint balance = callConfig.store.getBalance(token, account);
        if (amount > balance) revert PuppetLogic__InsufficientBalance();

        SafeERC20.safeTransferFrom(token, callConfig.positionRouterAddress, msg.sender, amount);

        callConfig.store.setBalance(token, account, balance - amount);

        emit PuppetLogic__Withdraw(token, account, amount);
    }

    function setRule(
        CallSetRuleConfig memory callConfig,
        IERC20 collateralToken,
        address puppet,
        address trader,
        PuppetStore.Rule calldata ruleParams
    ) internal {
        bytes32 ruleKey = PositionUtils.getRuleKey(collateralToken, puppet, trader);
        _validatePuppetTokenAllowance(callConfig.store, collateralToken, puppet);

        PuppetStore.Rule memory storedRule = callConfig.store.getRule(ruleKey);
        PuppetStore.Rule memory rule = _setRule(callConfig, storedRule, ruleParams);

        callConfig.store.setRule(ruleKey, rule);

        emit PuppetLogic__SetRule(ruleKey, rule);
    }

    function setRuleList(
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

        PuppetStore.Rule[] memory storedRuleList = callConfig.store.getRuleList(keyList);

        for (uint i = 0; i < length; i++) {
            storedRuleList[i] = _setRule(callConfig, storedRuleList[i], ruleParams[i]);

            if (isArrayContains(verifyAllowanceTokenList, collateralTokenList[i])) {
                verifyAllowanceTokenList[verifyAllowanceTokenList.length] = collateralTokenList[i];
            }

            emit PuppetLogic__SetRule(keyList[i], storedRuleList[i]);
        }

        callConfig.store.setRuleList(keyList, storedRuleList);

        _validatePuppetTokenAllowanceList(callConfig.store, verifyAllowanceTokenList, puppet);
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
