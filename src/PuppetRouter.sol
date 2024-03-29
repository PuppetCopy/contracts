// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {Router} from "./utils/Router.sol";
import {Router} from "./utils/Router.sol";

import {PuppetStore} from "./position/store/PuppetStore.sol";
import {PuppetLogic} from "./position/logic/PuppetLogic.sol";

contract PuppetRouter is Auth, ReentrancyGuard {
    event PuppetRouter__SetConfig(uint timestamp, CallConfig callConfig);

    struct CallConfig {
        PuppetLogic.CallSetRuleConfig setRule;
        PuppetLogic.CallCreateSubaccountConfig createSubaccount;
        PuppetLogic.CallSetDepositWntConfig setWnt;
    }

    CallConfig callConfig;

    constructor(Authority _authority, CallConfig memory _callConfig) Auth(address(0), _authority) {
        _setConfig(_callConfig);
    }

    function setRule(
        address collateralToken,
        address trader,
        PuppetStore.Rule calldata ruleParams //
    ) external nonReentrant {
        PuppetLogic.setRule(callConfig.setRule, trader, collateralToken, msg.sender, ruleParams);
    }

    function setRuleList(
        PuppetStore.Rule[] calldata ruleParams, //
        address[] calldata traderList,
        address[] calldata collateralTokenList
    ) external nonReentrant {
        PuppetLogic.setRuleList(callConfig.setRule, traderList, collateralTokenList, ruleParams, msg.sender);
    }

    function createSubaccount(address account) external nonReentrant {
        PuppetLogic.createSubaccount(callConfig.createSubaccount, account);
    }

    // governance

    function setConfig(CallConfig memory _callConfig) external requiresAuth {
        _setConfig(_callConfig);
    }

    function setTokenAllowanceCap(address token, uint amount) external requiresAuth {
        callConfig.setRule.store.setTokenAllowanceCap(token, amount);
    }

    // integration

    function setMatchingActivity(
        address collateralToken,
        address trader,
        address[] calldata _puppetList,
        uint[] calldata _activityList,
        uint[] calldata _allowanceOptimList
    ) external requiresAuth {
        callConfig.setRule.store.setMatchingActivity(collateralToken, trader, _puppetList, _activityList, _allowanceOptimList);
    }

    // internal

    function _setConfig(CallConfig memory _callConfig) internal {
        callConfig = _callConfig;

        emit PuppetRouter__SetConfig(block.timestamp, _callConfig);
    }

    error PuppetRouter__InvalidPuppet();
    error PuppetRouter__InvalidAllowance();
}
