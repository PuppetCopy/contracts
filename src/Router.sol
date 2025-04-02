// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Multicall} from "@openzeppelin/contracts/utils/Multicall.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";

import {GmxExecutionCallback} from "./position/GmxExecutionCallback.sol";

import {MatchRule} from "./position/MatchRule.sol";
import {MirrorPosition} from "./position/MirrorPosition.sol"; // Imports MirrorPosition and its structs
// import {AllocationAccount} from "./shared/AllocationAccount.sol"; // AllocationAccount not directly used here
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
    ) CoreContract(_authority) {}

    // --- MirrorPosition Interaction ---

    // /**
    //  * @notice Allocates capital from puppets for a trader.
    //  * @param params Allocation parameters including collateral token and trader.
    //  * @param puppetList List of puppet addresses (owners) to allocate from.
    //  * @return allocationId The unique ID for this allocation instance.
    //  */
    function allocate(
        MirrorPosition.CallPosition calldata params,
        address[] calldata puppetList
    ) external nonReentrant auth returns (uint _nextAllocationId, bytes32 _requestKey) {
        return config.position.mirror(params, puppetList);
    }

    /**
     * @notice Mirrors a trader's position action (increase or decrease).
     * @param params Position parameters including deltas, market, direction, and allocationId.
     * @param puppetList List of puppet addresses involved in the allocation.
     * @return nextAllocationId The next allocation ID for the position.
     * @return requestKey The unique key for this request.
     */
    function adjust(
        MirrorPosition.CallPosition calldata params,
        address[] calldata puppetList
    ) external payable nonReentrant auth returns (uint nextAllocationId, bytes32 requestKey) {
        return config.position.mirror{value: msg.value}(params, puppetList);
    }

    /**
     * @notice Settles funds back to puppets after a position is closed or adjusted.
     * @param params Settlement parameters including allocation details and token to distribute.
     * @param puppetList List of puppet addresses involved in the allocation.
     */
    function settle(
        MirrorPosition.CallSettle calldata params,
        address[] calldata puppetList
    ) external nonReentrant auth {
        // Updated call: pass the struct and puppetList
        config.position.settle(params, puppetList);
    }

    // --- MatchRule Interaction ---

    /**
     * @notice Deposits tokens into the system for a user (potential puppet).
     * @param token The token being deposited.
     * @param amount The amount being deposited.
     */
    function deposit(IERC20 token, uint amount) external nonReentrant {
        // Calls MatchRule, which interacts with AllocationStore using msg.sender
        config.matchRule.deposit(token, msg.sender, amount);
    }

    /**
     * @notice Withdraws tokens from the system for a user.
     * @param token The token being withdrawn.
     * @param receiver The address to receive the withdrawn tokens.
     * @param amount The amount being withdrawn.
     */
    function withdraw(IERC20 token, address receiver, uint amount) external nonReentrant {
        // Calls MatchRule, which interacts with AllocationStore using msg.sender
        config.matchRule.withdraw(token, msg.sender, receiver, amount);
    }

    /**
     * @notice Sets or updates the matching rule for the caller (puppet) regarding a specific trader.
     * @param collateralToken The token context for this rule.
     * @param trader The trader the caller wishes to potentially mirror.
     * @param ruleParams The parameters for the rule (allowance rate, throttle, expiry).
     */
    function setMatchRule(
        IERC20 collateralToken,
        address trader,
        MatchRule.Rule calldata ruleParams
    ) external nonReentrant {
        // Calls MatchRule, associating msg.sender with the trader rule
        config.matchRule.setRule(collateralToken, msg.sender, trader, ruleParams);
    }

    // --- Configuration ---

    function _setConfig(
        bytes calldata data
    ) internal override {
        config = abi.decode(data, (Config));
        // Add checks for valid addresses if needed
        require(address(config.matchRule) != address(0), "Router: Invalid MatchRule");
        require(address(config.position) != address(0), "Router: Invalid MirrorPosition");
        // require(address(config.executionCallback) != address(0), "Router: Invalid ExecutionCallback"); // Callback
        // might be optional depending on flow
        require(address(config.feeMarketplace) != address(0), "Router: Invalid FeeMarketplace");
    }
}
