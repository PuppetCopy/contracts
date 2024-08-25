// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {PuppetLogic} from "./puppet/PuppetLogic.sol";
import {PuppetStore} from "./puppet/store/PuppetStore.sol";
import {CoreContract} from "./utils/CoreContract.sol";
import {EventEmitter} from "./utils/EventEmitter.sol";
import {ReentrancyGuardTransient} from "./utils/ReentrancyGuardTransient.sol";
import {Auth} from "./utils/access/Auth.sol";
import {IAuthority} from "./utils/interfaces/IAuthority.sol";

contract PuppetRouter is CoreContract, ReentrancyGuardTransient {
    struct Config {
        PuppetLogic logic;
    }

    Config config;

    constructor(
        IAuthority _authority,
        EventEmitter _eventEmitter,
        Config memory _config
    ) CoreContract("PuppetRouter", "1", _authority, _eventEmitter) {
        setConfig(_config);
    }

    function deposit(IERC20 token, uint amount) external nonReentrant {
        config.logic.deposit(token, msg.sender, amount);
    }

    function withdraw(IERC20 token, address receiver, uint amount) external nonReentrant {
        config.logic.withdraw(token, msg.sender, receiver, amount);
    }

    function setRule(
        IERC20 collateralToken,
        address trader,
        PuppetStore.Rule calldata ruleParams //
    ) external nonReentrant {
        config.logic.setRule(collateralToken, msg.sender, trader, ruleParams);
    }

    function setRuleList(
        PuppetStore.Rule[] calldata ruleParams, //
        address[] calldata traderList,
        IERC20[] calldata collateralTokenList
    ) external nonReentrant {
        config.logic.setRuleList(msg.sender, traderList, collateralTokenList, ruleParams);
    }

    // governance

    function setConfig(Config memory _config) public auth {
        config = _config;

        logEvent("setConfig()", abi.encode(_config));
    }

    // internal

    error PuppetRouter__InvalidPuppet();
    error PuppetRouter__InvalidAllowance();
}
