// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {Router} from "./utils/Router.sol";
import {Router} from "./utils/Router.sol";

import {Calc} from "./utils/Calc.sol";

import {SubaccountStore} from "./shared/store/SubaccountStore.sol";
import {PuppetStore} from "./position/store/PuppetStore.sol";
import {PuppetLogic} from "./position/logic/PuppetLogic.sol";

contract PuppetRouter is Auth, ReentrancyGuard {
    event PuppetRouter__SetConfig(uint timestamp, PuppetLogic.CallSetRuleConfig callSetRuleConfig);

    struct PuppetRouterParams {
        PuppetStore puppetStore;
        Router router;
        SubaccountStore subaccountStore;
    }

    PuppetLogic.CallSetRuleConfig callSetRuleConfig;

    constructor(Authority _authority, PuppetLogic.CallSetRuleConfig memory _callSetRuleConfig) Auth(address(0), _authority) {
        _setConfig(_callSetRuleConfig);
    }

    function setRule(PuppetStore.Rule calldata ruleParams) external nonReentrant {
        PuppetLogic.setRule(callSetRuleConfig, ruleParams, msg.sender);
    }

    function setRuleList(PuppetStore.Rule[] calldata ruleParams, address[] calldata traderList) external nonReentrant {
        PuppetLogic.setRuleList(callSetRuleConfig, ruleParams, traderList, msg.sender);
    }

    // governance

    function setConfig(PuppetLogic.CallSetRuleConfig calldata _callSetRuleConfig) external requiresAuth {
        _setConfig(_callSetRuleConfig);
    }

    // internal

    function _setConfig(PuppetLogic.CallSetRuleConfig memory _callSetRuleConfig) internal {
        callSetRuleConfig = _callSetRuleConfig;

        if (callSetRuleConfig.minAllowanceRate == 0 || callSetRuleConfig.maxAllowanceRate > Calc.BASIS_POINT_DIVISOR) {
            revert PuppetRouter__InvalidAllowance();
        }

        emit PuppetRouter__SetConfig(block.timestamp, callSetRuleConfig);
    }

    error PuppetRouter__InvalidPuppet();
    error PuppetRouter__InvalidAllowance();
}
