// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";

import {MirrorPosition} from "./position/MirrorPosition.sol";
import {MatchingRule} from "./position/MatchingRule.sol";
import {FeeMarketplace} from "./shared/FeeMarketplace.sol";

/**
 * @title UserRouter
 * @notice Handles user-facing operations for the copy trading system
 * @dev Contains deposit, withdraw, rule setting, and offer acceptance functionality
 */
contract UserRouter is ReentrancyGuardTransient {
    MatchingRule public immutable matchingRule;
    FeeMarketplace public immutable feeMarketplace;
    MirrorPosition public immutable mirrorPosition;

    constructor(MatchingRule _matchingRule, FeeMarketplace _feeMarketplace, MirrorPosition _mirrorPosition) {
        matchingRule = _matchingRule;
        feeMarketplace = _feeMarketplace;
        mirrorPosition = _mirrorPosition;
    }

    /**
     * @notice Deposits tokens into the system for a user.
     * @param token The token being deposited.
     * @param amount The amount being deposited.
     */
    function deposit(IERC20 token, uint amount) external nonReentrant {
        matchingRule.deposit(token, msg.sender, msg.sender, amount);
    }

    /**
     * @notice Withdraws tokens from the system for a user.
     * @param token The token being withdrawn.
     * @param receiver The address to receive the withdrawn tokens.
     * @param amount The amount being withdrawn.
     */
    function withdraw(IERC20 token, address receiver, uint amount) external nonReentrant {
        matchingRule.withdraw(token, msg.sender, receiver, amount);
    }

    /**
     * @notice Sets or updates the matching rule for the caller (puppet) regarding a specific trader.
     * @param collateralToken The token context for this rule.
     * @param trader The trader the caller wishes to potentially mirror.
     * @param ruleParams The parameters for the rule (allowance rate, throttle, expiry).
     */
    function setMatchingRule(
        IERC20 collateralToken,
        address trader,
        MatchingRule.Rule calldata ruleParams
    ) external nonReentrant {
        matchingRule.setRule(mirrorPosition, collateralToken, msg.sender, trader, ruleParams);
    }

    /**
     * @notice Executes a fee redemption offer.
     * @param feeToken The fee token to be redeemed.
     * @param receiver The address receiving the fee tokens.
     * @param purchaseAmount The amount of fee tokens to redeem.
     */
    function acceptOffer(IERC20 feeToken, address receiver, uint purchaseAmount) external nonReentrant {
        feeMarketplace.acceptOffer(feeToken, msg.sender, receiver, purchaseAmount);
    }
}
