// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

import {PuppetStore} from "./position/store/PuppetStore.sol";
import {PuppetLogic} from "./position/logic/PuppetLogic.sol";

contract PuppetRouter is Auth, EIP712, ReentrancyGuard {
    event PuppetRouter__SetConfig(uint timestamp, CallConfig callConfig);

    struct CallConfig {
        PuppetLogic.CallSetRuleConfig setRule;
        PuppetLogic.CallCreateSubaccountConfig createSubaccount;
        PuppetLogic.CallSetBalanceConfig setBalance;
    }

    CallConfig callConfig;

    constructor(
        Authority _authority,
        CallConfig memory _callConfig,
        IERC20[] memory _tokenAllowanceCapList,
        uint[] memory _tokenAllowanceCapAmountList
    ) Auth(address(0), _authority) EIP712("Puppet Router", "1") {
        _setConfig(_callConfig, _tokenAllowanceCapList, _tokenAllowanceCapAmountList);
    }

    function deposit(IERC20 token, uint amount) external nonReentrant {
        PuppetLogic.deposit(callConfig.setBalance, token, msg.sender, amount);
    }

    function withdraw(IERC20 token, address receiver, uint amount) external nonReentrant {
        PuppetLogic.withdraw(callConfig.setBalance, token, msg.sender, receiver, amount);
    }

    function setRule(
        IERC20 collateralToken,
        address trader,
        PuppetStore.Rule calldata ruleParams //
    ) external nonReentrant {
        PuppetLogic.setRule(callConfig.setRule, collateralToken, msg.sender, trader, ruleParams);
    }

    function setRuleList(
        PuppetStore.Rule[] calldata ruleParams, //
        address[] calldata traderList,
        IERC20[] calldata collateralTokenList
    ) external nonReentrant {
        PuppetLogic.setRuleList(callConfig.setRule, msg.sender, traderList, collateralTokenList, ruleParams);
    }

    function createSubaccount() external nonReentrant {
        PuppetLogic.createSubaccount(callConfig.createSubaccount, msg.sender);
    }

    // governance

    function setConfig(
        CallConfig memory _callConfig, //
        IERC20[] memory _tokenAllowanceCapList,
        uint[] memory _tokenAllowanceCapAmountList
    ) external requiresAuth {
        _setConfig(_callConfig, _tokenAllowanceCapList, _tokenAllowanceCapAmountList);
    }

    // integration

    function decreaseBalanceAndSetActivityList(
        PuppetStore store,
        IERC20 token,
        address receiver,
        address trader,
        uint _activityTime,
        address[] calldata _puppetList,
        uint[] calldata _balanceList
    ) external requiresAuth {
        store.decreaseBalanceAndSetActivityList(token, receiver, trader, _activityTime, _puppetList, _balanceList);
    }

    // internal

    function _setConfig(CallConfig memory _callConfig, IERC20[] memory _tokenAllowanceCapList, uint[] memory _tokenAllowanceCapAmountList) internal {
        if (_tokenAllowanceCapList.length != _tokenAllowanceCapAmountList.length) revert PuppetRouter__InvalidListLength();

        for (uint i; i < _tokenAllowanceCapList.length; i++) {
            IERC20 _token = _tokenAllowanceCapList[i];
            _callConfig.setRule.store.setTokenAllowanceCap(_token, _tokenAllowanceCapAmountList[i]);
        }

        callConfig = _callConfig;

        emit PuppetRouter__SetConfig(block.timestamp, _callConfig);
    }

    error PuppetRouter__InvalidPuppet();
    error PuppetRouter__InvalidAllowance();
    error PuppetRouter__InvalidListLength();
}
