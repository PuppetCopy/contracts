// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Router} from "./utils/Router.sol";
import {Router} from "./utils/Router.sol";

import {PuppetStore} from "./position/store/PuppetStore.sol";
import {PuppetLogic} from "./position/logic/PuppetLogic.sol";

contract PuppetRouter is Auth, ReentrancyGuard {
    event PuppetRouter__SetConfig(uint timestamp, CallConfig callConfig);

    struct CallConfig {
        PuppetLogic.CallSetRuleConfig setRule;
        PuppetLogic.CallCreateSubaccountConfig createSubaccount;
        PuppetLogic.CallSetBalanceConfig setBalance;
    }

    CallConfig callConfig;

    constructor(Authority _authority, CallConfig memory _callConfig) Auth(address(0), _authority) {
        _setConfig(_callConfig);
    }

    function deposit(IERC20 token, uint amount) external nonReentrant {
        PuppetLogic.deposit(callConfig.setBalance, token, msg.sender, amount);
    }

    function withdraw(IERC20 token, address receiver, uint amount) external nonReentrant {
        PuppetLogic.withdraw(callConfig.setBalance, token, msg.sender, receiver, amount);
    }

    function setRule(
        IERC20 collateralToken,
        address trader,
        PuppetStore.Rule calldata ruleParams //
    ) external nonReentrant {
        PuppetLogic.setRule(callConfig.setRule, collateralToken, msg.sender, trader, ruleParams);
    }

    function setRuleList(
        PuppetStore.Rule[] calldata ruleParams, //
        address[] calldata traderList,
        IERC20[] calldata collateralTokenList
    ) external nonReentrant {
        PuppetLogic.setRuleList(callConfig.setRule, msg.sender, traderList, collateralTokenList, ruleParams);
    }

    function createSubaccount() external nonReentrant {
        PuppetLogic.createSubaccount(callConfig.createSubaccount, msg.sender);
    }

    // governance

    function setConfig(CallConfig memory _callConfig) external requiresAuth {
        _setConfig(_callConfig);
    }

    function setTokenAllowanceCap(IERC20 token, uint amount) external requiresAuth {
        callConfig.setRule.store.setTokenAllowanceCap(token, amount);
    }

    // integration

    function decreaseBalanceAndSetActivityList(
        PuppetStore store,
        IERC20 token,
        address receiver,
        address trader,
        address[] calldata _puppetList,
        uint[] calldata _activityList,
        uint[] calldata _balanceList
    ) external requiresAuth {
        store.decreaseBalanceAndSetActivityList(token, receiver, trader, _puppetList, _activityList, _balanceList);
    }

    // internal

    function _setConfig(CallConfig memory _callConfig) internal {
        callConfig = _callConfig;

        emit PuppetRouter__SetConfig(block.timestamp, _callConfig);
    }

    error PuppetRouter__InvalidPuppet();
    error PuppetRouter__InvalidAllowance();
}
