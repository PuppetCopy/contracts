// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {Auth} from "../utils/access/Auth.sol";

import {PuppetStore} from "./store/PuppetStore.sol";
import {PuppetLogic} from "./logic/PuppetLogic.sol";

contract PuppetRouter is Auth, EIP712, ReentrancyGuard {
    event PuppetRouter__SetConfig(uint timestamp, CallConfig callConfig);

    struct CallConfig {
        PuppetLogic.CallSetRuleConfig setRule;
    }

    CallConfig callConfig;
    PuppetStore store;

    constructor(IAuthority _authority, PuppetStore _store, CallConfig memory _callConfig) Auth(_authority) EIP712("Puppet Router", "1") {
        store = _store;
        _setConfig(_callConfig);
    }

    function deposit(IERC20 token, uint amount) external nonReentrant {
        PuppetLogic.deposit(store, token, msg.sender, amount);
    }

    function withdraw(IERC20 token, address receiver, uint amount) external nonReentrant {
        PuppetLogic.withdraw(store, token, msg.sender, receiver, amount);
    }

    function setRule(
        IERC20 collateralToken,
        address trader,
        PuppetStore.Rule calldata ruleParams //
    ) external nonReentrant {
        PuppetLogic.setRule(store, callConfig.setRule, collateralToken, msg.sender, trader, ruleParams);
    }

    function setRuleList(
        PuppetStore.Rule[] calldata ruleParams, //
        address[] calldata traderList,
        IERC20[] calldata collateralTokenList
    ) external nonReentrant {
        PuppetLogic.setRuleList(store, callConfig.setRule, msg.sender, traderList, collateralTokenList, ruleParams);
    }

    // governance

    function setConfig(CallConfig memory _callConfig) external auth {
        _setConfig(_callConfig);
    }

    // internal

    function _setConfig(CallConfig memory _callConfig) internal {
        callConfig = _callConfig;

        emit PuppetRouter__SetConfig(block.timestamp, _callConfig);
    }

    error PuppetRouter__InvalidPuppet();
    error PuppetRouter__InvalidAllowance();
}
