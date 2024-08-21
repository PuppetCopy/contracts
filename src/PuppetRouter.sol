// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ReentrancyGuardTransient} from "./utils/ReentrancyGuardTransient.sol";
import {Auth} from "./utils/access/Auth.sol";
import {IAuthority} from "./utils/interfaces/IAuthority.sol";

import {PuppetLogic} from "./puppet/PuppetLogic.sol";
import {PuppetStore} from "./puppet/store/PuppetStore.sol";

contract PuppetRouter is Auth, ReentrancyGuardTransient {
    event PuppetRouter__SetConfig(uint timestamp, Config config);

    struct Config {
        PuppetLogic logic;
    }

    Config config;

    constructor(IAuthority _authority, Config memory _config) Auth(_authority) {
        _setConfig(_config);
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

    function setConfig(Config memory _config) external auth {
        _setConfig(_config);
    }

    // internal

    function _setConfig(Config memory _config) internal {
        config = _config;

        emit PuppetRouter__SetConfig(block.timestamp, _config);
    }

    error PuppetRouter__InvalidPuppet();
    error PuppetRouter__InvalidAllowance();
}
