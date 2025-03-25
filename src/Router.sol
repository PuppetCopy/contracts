// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Multicall} from "@openzeppelin/contracts/utils/Multicall.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";

import {GmxExecutionCallback} from "./position/GmxExecutionCallback.sol";

import {MatchRule} from "./position/MatchRule.sol";
import {MirrorPosition} from "./position/MirrorPosition.sol";
import {AllocationAccount} from "./shared/AllocationAccount.sol";
import {FeeMarketplace} from "./tokenomics/FeeMarketplace.sol";
import {CoreContract} from "./utils/CoreContract.sol";
import {IAuthority} from "./utils/interfaces/IAuthority.sol";

contract Router is CoreContract, ReentrancyGuardTransient, Multicall {
    // Position module configuration.
    struct Config {
        MatchRule matchRule;
        MirrorPosition position;
        GmxExecutionCallback executionCallback;
        FeeMarketplace feeMarketplace;
    }

    Config public config;

    constructor(
        IAuthority _authority
    ) CoreContract("Router", _authority) {}

    function allocate(
        MirrorPosition.PositionParams calldata params,
        address[] calldata puppetList
    ) external nonReentrant auth returns (uint) {
        return config.position.allocate(params, puppetList);
    }

    function mirror(
        MirrorPosition.PositionParams calldata params,
        address[] calldata puppetList,
        uint allocationId
    ) external payable nonReentrant auth returns (bytes32 requestKey) {
        requestKey = config.position.mirror(params, puppetList, allocationId);
    }

    function settle(
        IERC20 token, //
        address trader,
        address[] calldata puppetList,
        uint allocationId
    ) external nonReentrant auth {
        config.position.settle(token, trader, puppetList, allocationId);
    }

    function deposit(IERC20 token, uint amount) external nonReentrant {
        config.matchRule.deposit(token, msg.sender, amount);
    }

    function withdraw(IERC20 token, address receiver, uint amount) external nonReentrant {
        config.matchRule.withdraw(token, msg.sender, receiver, amount);
    }

    function setMatchRule(
        IERC20 collateralToken,
        address trader,
        MatchRule.Rule calldata ruleParams
    ) external nonReentrant {
        config.matchRule.setRule(collateralToken, msg.sender, trader, ruleParams);
    }

    function _setConfig(
        bytes calldata data
    ) internal override {
        config = abi.decode(data, (Config));
    }
}
