// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {PuppetLogic} from "./puppet/PuppetLogic.sol";
import {PuppetStore} from "./puppet/store/PuppetStore.sol";
import {CoreContract} from "./utils/CoreContract.sol";
import {EventEmitter} from "./utils/EventEmitter.sol";
import {ReentrancyGuardTransient} from "./utils/ReentrancyGuardTransient.sol";
import {Access} from "./utils/auth/Access.sol";
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
        PuppetStore.AllocationRule calldata ruleParams,
        address puppet
    ) external nonReentrant {
        config.logic.setAllocationRule(collateralToken, puppet, ruleParams);
    }

    function setMatchRule(
        IERC20 collateralToken,
        PuppetStore.MatchRule calldata ruleParams,
        address trader
    ) external nonReentrant {
        config.logic.setMatchRule(collateralToken, ruleParams, msg.sender, trader);
    }

    function setMatchRuleList(
        IERC20[] calldata collateralTokenList,
        PuppetStore.MatchRule[] calldata ruleParams,
        address[] calldata traderList
    ) external nonReentrant {
        config.logic.setMatchRuleList(collateralTokenList, traderList, ruleParams, msg.sender);
    }

    // governance

    /// @notice Set the mint rate limit for the token.
    /// @param _config The new rate limit configuration.
    function setConfig(Config calldata _config) external auth {
        config = _config;
        logEvent("SetConfig", abi.encode(_config));
    }
}
