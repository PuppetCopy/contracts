// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Multicall} from "@openzeppelin/contracts/utils/Multicall.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";

import {PuppetLogic} from "./puppet/PuppetLogic.sol";
import {PuppetStore} from "./puppet/store/PuppetStore.sol";
import {CoreContract} from "./utils/CoreContract.sol";
import {Access} from "./utils/auth/Access.sol";
import {IAuthority} from "./utils/interfaces/IAuthority.sol";

contract PuppetRouter is CoreContract, ReentrancyGuardTransient, Multicall {
    struct Config {
        PuppetLogic logic;
    }

    Config public config;

    constructor(
        IAuthority _authority
    ) CoreContract("PuppetRouter", "1", _authority) {}

    function deposit(IERC20 token, uint amount) external nonReentrant {
        config.logic.deposit(token, msg.sender, amount);
    }

    function withdraw(IERC20 token, address receiver, uint amount) external nonReentrant {
        config.logic.withdraw(token, msg.sender, receiver, amount);
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
        address[] calldata traderList,
        PuppetStore.MatchRule[] calldata ruleParams
    ) external nonReentrant {
        config.logic.setMatchRuleList(collateralTokenList, traderList, ruleParams, msg.sender);
    }

    // governance

    function _setConfig(
        bytes calldata data
    ) internal override {
        config = abi.decode(data, (Config));
    }
}
