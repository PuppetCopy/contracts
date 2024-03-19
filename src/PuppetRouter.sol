// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Multicall} from "@openzeppelin/contracts/utils/Multicall.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {Router} from "./utils/Router.sol";
import {Router} from "./utils/Router.sol";
import {Dictator} from "./utils/Dictator.sol";

import {PuppetUtils} from "./position/util/PuppetUtils.sol";
import {SubaccountLogic} from "./position/util/SubaccountLogic.sol";

import {SubaccountStore} from "./position/store/SubaccountStore.sol";
import {PuppetStore} from "./position/store/PuppetStore.sol";
import {PuppetLogic} from "./position/PuppetLogic.sol";

contract PuppetRouter is Router, Multicall, ReentrancyGuard {
    event PuppetRouter__SetConfig(uint timestamp, PuppetRouterConfig config);

    struct PuppetRouterParams {
        PuppetStore puppetStore;
        Router router;
        SubaccountStore subaccountStore;
    }

    struct PuppetRouterConfig {
        PuppetLogic puppetLogic;
        SubaccountLogic subaccountLogic;
        address dao;
        uint minExpiryDuration;
        uint minAllowanceRate;
        uint maxAllowanceRate;
    }

    PuppetRouterConfig config;
    PuppetRouterParams params;

    constructor(Dictator dictator, PuppetRouterParams memory _params, PuppetRouterConfig memory _config) Router(dictator) {
        params = _params;
        _setConfig(_config);
    }

    function createSubaccount(address account) external nonReentrant {
        config.subaccountLogic.createSubaccount(params.subaccountStore, account);
    }

    function setRule(PuppetStore.Rule calldata ruleParams, address collateralToken, address trader) external nonReentrant {
        bytes32 key = PuppetUtils.getRouteKey(trader, collateralToken);

        _setRule(msg.sender, key, ruleParams);
    }

    function setRule(PuppetStore.Rule calldata ruleParams, bytes32 key) external nonReentrant {
        _setRule(msg.sender, key, ruleParams);
    }

    function setRuleList(bytes32[] calldata routeKeyList, PuppetStore.Rule[] calldata ruleParams, address[] calldata traderList)
        external
        nonReentrant
    {
        uint length = traderList.length;
        for (uint i = 0; i < length; i++) {
            _setRule(msg.sender, routeKeyList[i], ruleParams[i]);
        }
    }

    // internal

    function _setRule(address puppet, bytes32 routeKey, PuppetStore.Rule calldata ruleParams) internal {
        PuppetLogic.CallSetRuleParams memory callParams = PuppetLogic.CallSetRuleParams({
            store: params.puppetStore,
            minExpiryDuration: config.minExpiryDuration,
            minAllowanceRate: config.minAllowanceRate,
            maxAllowanceRate: config.maxAllowanceRate
        });

        config.puppetLogic.setRule(callParams, ruleParams, PuppetUtils.getPuppetRouteKey(puppet, routeKey));
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

    error PuppetRouter__InvalidPuppet();
}
