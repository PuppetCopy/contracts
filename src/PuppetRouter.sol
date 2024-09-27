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

    Config public config;

    constructor(
        IAuthority _authority,
        EventEmitter _eventEmitter
    ) CoreContract("PuppetRouter", "1", _authority, _eventEmitter) {}

    function deposit(IERC20 token, uint amount) external nonReentrant {
        config.logic.deposit(token, msg.sender, amount);
    }

    function withdraw(IERC20 token, address receiver, uint amount) external nonReentrant {
        config.logic.withdraw(token, msg.sender, receiver, amount);
    }

    function setAllocationRule(
        IERC20 collateralToken,
        address trader,
        PuppetStore.RouteAllocationRule calldata ruleParams //
    ) external nonReentrant {
        config.logic.setAllocationRule(collateralToken, msg.sender, trader, ruleParams);
    }

    function setAllocationRuleList(
        PuppetStore.RouteAllocationRule[] calldata ruleParams, //
        address[] calldata traderList,
        IERC20[] calldata collateralTokenList
    ) external nonReentrant {
        config.logic.setAllocationRuleList(collateralTokenList, msg.sender, traderList, ruleParams);
    }

    // governance

    /// @notice Set the mint rate limit for the token.
    /// @param _config The new rate limit configuration.
    function setConfig(Config calldata _config) external auth {
        config = _config;
        logEvent("SetConfig", abi.encode(_config));
    }
}
