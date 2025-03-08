// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Multicall} from "@openzeppelin/contracts/utils/Multicall.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";

import {GmxExecutionCallback} from "./position/GmxExecutionCallback.sol";
import {MatchRule} from "./position/MatchRule.sol";
import {MirrorPosition} from "./position/MirrorPosition.sol";
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
    ) CoreContract("Router", "1", _authority) {}

    /**
     * @notice Allocates collateral for a position.
     */
    function allocate(
        IERC20 collateralToken,
        bytes32 sourceRequestKey,
        bytes32 positionKey,
        bytes32 matchKey,
        address[] calldata puppetList
    ) external nonReentrant auth returns (bytes32 allocationKey) {
        allocationKey = config.position.allocate(collateralToken, sourceRequestKey, positionKey, matchKey, puppetList);
    }

    /**
     * @notice Mirrors a position.
     */
    function mirror(
        MirrorPosition.MirrorPositionParams calldata params
    ) external payable nonReentrant auth returns (bytes32 requestKey) {
        requestKey = config.position.mirror(params);
    }

    /**
     * @notice Settles an allocated position.
     */
    function settle(bytes32 key, address[] calldata puppetList) external nonReentrant auth {
        config.position.settle(key, puppetList);
    }

    /**
     * @notice Deposits tokens.
     */
    function deposit(IERC20 token, uint amount) external nonReentrant {
        config.matchRule.deposit(token, msg.sender, amount);
    }

    /**
     * @notice Withdraws tokens.
     */
    function withdraw(IERC20 token, address receiver, uint amount) external nonReentrant {
        config.matchRule.withdraw(token, msg.sender, receiver, amount);
    }

    /**
     * @notice Sets a list of match rules.
     */
    function setMatchRule(
        IERC20 collateralToken,
        address trader,
        MatchRule.Rule calldata ruleParams
    ) external nonReentrant {
        config.matchRule.setRule(collateralToken, msg.sender, trader, ruleParams);
    }

    /**
     * @notice Sets the configuration for both modules.
     * @dev Receives a single bytes-encoded CombinedConfig.
     */
    function _setConfig(
        bytes calldata data
    ) internal override {
        config = abi.decode(data, (Config));
    }
}
