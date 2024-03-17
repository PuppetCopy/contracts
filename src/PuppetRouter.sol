// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Multicall} from "@openzeppelin/contracts/utils/Multicall.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {Router} from "./utils/Router.sol";
import {Router} from "./utils/Router.sol";
import {Dictator} from "./utils/Dictator.sol";

import {PuppetStore} from "./position/store/PuppetStore.sol";
import {PuppetLogic} from "./position/PuppetLogic.sol";

contract PuppetRouter is Router, Multicall, ReentrancyGuard {
    event PuppetRouter__SetConfig(uint timestamp, PuppetRouterConfig config);

    struct PuppetRouterParams {
        PuppetStore puppetStore;
        Router router;
    }

    struct PuppetRouterConfig {
        PuppetLogic puppetLogic;
        address dao;
        uint minExpiryDuration;
        uint minAllowanceRate;
        uint maxAllowanceRate;
    }

    PuppetRouterConfig config;
    PuppetRouterParams params;

    constructor(Dictator dictator, PuppetRouterConfig memory _config, PuppetRouterParams memory _params) Router(dictator) {
        _setConfig(_config);
        params = _params;
    }

    function setRule(PuppetStore.Rule calldata ruleParams) external nonReentrant {
        PuppetLogic.CallSetRuleParams memory callParams = PuppetLogic.CallSetRuleParams({
            store: params.puppetStore,
            minExpiryDuration: config.minExpiryDuration,
            minAllowanceRate: config.minAllowanceRate,
            maxAllowanceRate: config.maxAllowanceRate,
            puppet: msg.sender
        });

        config.puppetLogic.setRule(callParams, ruleParams);
    }

    function removeRule(address trader) external nonReentrant {
        config.puppetLogic.removeRule(params.puppetStore, msg.sender, trader);
    }

    // governance

    function setConfig(PuppetRouterConfig memory _config) external requiresAuth {
        _setConfig(_config);
    }

    // internal

    function _setConfig(PuppetRouterConfig memory _config) internal {
        config = _config;

        emit PuppetRouter__SetConfig(block.timestamp, _config);
    }
}
