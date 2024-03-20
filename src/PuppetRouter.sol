// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Multicall} from "@openzeppelin/contracts/utils/Multicall.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {Router} from "./utils/Router.sol";
import {Router} from "./utils/Router.sol";
import {Dictator} from "./utils/Dictator.sol";

import {Calc} from "./utils/Calc.sol";

import {SubaccountStore} from "./position/store/SubaccountStore.sol";
import {PuppetStore} from "./position/store/PuppetStore.sol";
import {PuppetLogic} from "./position/PuppetLogic.sol";

contract PuppetRouter is Router, Multicall, ReentrancyGuard {
    event PuppetRouter__SetConfig(uint timestamp, PuppetLogic.CallSetRuleConfig callSetRuleConfig);

    struct PuppetRouterParams {
        PuppetStore puppetStore;
        Router router;
        SubaccountStore subaccountStore;
    }

    PuppetLogic.CallSetRuleConfig callSetRuleConfig;
    PuppetLogic puppetLogic;

    constructor(Dictator dictator, PuppetLogic _puppetLogic, PuppetLogic.CallSetRuleConfig memory _callSetRuleConfig) Router(dictator) {
        puppetLogic = _puppetLogic;
        _setConfig(_callSetRuleConfig);
    }

    function setRule(PuppetStore.Rule calldata ruleParams) external nonReentrant {
        _setRule(msg.sender, ruleParams);
    }

    function setRuleList(PuppetStore.Rule[] calldata ruleParams, address[] calldata traderList) external nonReentrant {
        uint length = traderList.length;
        for (uint i = 0; i < length; i++) {
            _setRule(msg.sender, ruleParams[i]);
        }
    }

    // internal

    function _setRule(address puppet, PuppetStore.Rule calldata ruleParams) internal {
        puppetLogic.setRule(callSetRuleConfig, ruleParams, puppet);
    }

    // governance

    function setPuppetLogic(PuppetLogic _puppetLogic) external requiresAuth {
        puppetLogic = _puppetLogic;
    }

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
