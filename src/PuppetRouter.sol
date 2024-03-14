// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Multicall} from "@openzeppelin/contracts/utils/Multicall.sol";

import {Router} from "./utils/Router.sol";
import {Router} from "./utils/Router.sol";
import {Dictator} from "./utils/Dictator.sol";

import {PuppetStore} from "./position/store/PuppetStore.sol";
import {PuppetLogic} from "./position/PuppetLogic.sol";
import {PuppetUtils} from "./position/util/PuppetUtils.sol";

contract PuppetRouter is Router, Multicall {
    Router router;
    PuppetUtils.ConfigParams config;

    PuppetStore public immutable puppetStore;
    PuppetLogic puppetLogic;

    constructor(Dictator dictator, Router _router, PuppetUtils.ConfigParams memory _config, PuppetStore _puppetStore, PuppetLogic _puppetLogc)
        Router(dictator)
    {
        router = _router;
        puppetStore = _puppetStore;
        config = _config;
        puppetLogic = _puppetLogc;
    }

    function setRule(address puppet, PuppetStore.Rule calldata ruleParams) external {
        puppetLogic.setRule(config, puppetStore, puppet, ruleParams);
    }

    function removeRule(address puppet, address trader) external {
        puppetLogic.removeRule(puppetStore, puppet, trader);
    }

    function deposit(IERC20 token, address to, uint amount) external {
        puppetLogic.deposit(router, puppetStore, token, msg.sender, to, amount);
    }

    function withdraw(IERC20 token, address to, uint amount) external {
        puppetLogic.withdraw(router, puppetStore, token, msg.sender, to, amount);
    }

    // governance

    function setConfig(PuppetUtils.ConfigParams memory _config) external requiresAuth {
        config = _config;
    }

    function setPuppetLogic(PuppetLogic _puppetLogic) external requiresAuth {
        puppetLogic = _puppetLogic;
    }
}
