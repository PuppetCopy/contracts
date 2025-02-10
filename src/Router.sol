// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Multicall} from "@openzeppelin/contracts/utils/Multicall.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";

// Imports from your project
import {AllocationLogic} from "./position/AllocationLogic.sol";
import {ExecutionLogic} from "./position/ExecutionLogic.sol";
import {RequestLogic} from "./position/RequestLogic.sol";
import {UnhandledCallbackLogic} from "./position/UnhandledCallbackLogic.sol";
import {IGmxOrderCallbackReceiver} from "./position/interface/IGmxOrderCallbackReceiver.sol";
import {PositionStore} from "./position/store/PositionStore.sol";
import {GmxPositionUtils} from "./position/utils/GmxPositionUtils.sol";
import {PuppetLogic} from "./puppet/PuppetLogic.sol";
import {PuppetStore} from "./puppet/store/PuppetStore.sol";
import {FeeMarketplace} from "./tokenomics/FeeMarketplace.sol";
import {CoreContract} from "./utils/CoreContract.sol";
import {IAuthority} from "./utils/interfaces/IAuthority.sol";

contract Router is CoreContract, ReentrancyGuardTransient, Multicall {
    // Position module configuration.
    struct Config {
        RequestLogic requestLogic;
        AllocationLogic allocationLogic;
        ExecutionLogic executionLogic;
        PuppetLogic puppetLogic;
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
        allocationKey =
            config.allocationLogic.allocate(collateralToken, sourceRequestKey, positionKey, matchKey, puppetList);
    }

    /**
     * @notice Mirrors a position.
     */
    function mirror(
        RequestLogic.MirrorPositionParams calldata params
    ) external payable nonReentrant auth returns (bytes32 requestKey) {
        requestKey = config.requestLogic.mirror(params);
    }

    /**
     * @notice Settles an allocated position.
     */
    function settle(bytes32 key, address[] calldata puppetList) external nonReentrant auth {
        config.allocationLogic.settle(key, puppetList);
    }

    /**
     * @notice Deposits tokens.
     */
    function deposit(IERC20 token, uint amount) external nonReentrant {
        config.puppetLogic.deposit(token, msg.sender, amount);
    }

    /**
     * @notice Withdraws tokens.
     */
    function withdraw(IERC20 token, address receiver, uint amount) external nonReentrant {
        config.puppetLogic.withdraw(token, msg.sender, receiver, amount);
    }

    /**
     * @notice Sets a match rule.
     */
    function setMatchRule(
        IERC20 collateralToken,
        PuppetStore.MatchRule calldata ruleParams,
        address trader
    ) external nonReentrant {
        config.puppetLogic.setMatchRule(collateralToken, ruleParams, msg.sender, trader);
    }

    /**
     * @notice Sets a list of match rules.
     */
    function setMatchRuleList(
        IERC20[] calldata collateralTokenList,
        address[] calldata traderList,
        PuppetStore.MatchRule[] calldata ruleParams
    ) external nonReentrant {
        config.puppetLogic.setMatchRuleList(collateralTokenList, traderList, ruleParams, msg.sender);
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
