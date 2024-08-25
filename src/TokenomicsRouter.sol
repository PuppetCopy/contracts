// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {RevenueLogic} from "./tokenomics/RevenueLogic.sol";
import {RewardLogic} from "./tokenomics/RewardLogic.sol";
import {VotingEscrowLogic} from "./tokenomics/VotingEscrowLogic.sol";
import {CoreContract} from "./utils/CoreContract.sol";
import {EventEmitter} from "./utils/EventEmitter.sol";
import {ReentrancyGuardTransient} from "./utils/ReentrancyGuardTransient.sol";
import {Auth} from "./utils/access/Auth.sol";
import {IAuthority} from "./utils/interfaces/IAuthority.sol";

contract TokenomicsRouter is CoreContract, ReentrancyGuardTransient {
    struct Config {
        RewardLogic rewardLogic;
        VotingEscrowLogic veLogic;
        RevenueLogic revenueLogic;
    }

    Config config;

    constructor(
        IAuthority _authority,
        EventEmitter _eventEmitter,
        Config memory _config
    ) CoreContract("TokenomicsRouter", "1", _authority, _eventEmitter) {
        setConfig(_config);
    }

    function lockContribution(IERC20 token, uint amount, uint duration) external nonReentrant returns (uint reward) {
        config.revenueLogic.claim(token, msg.sender, msg.sender, amount);

        reward = config.rewardLogic.lock(token, msg.sender, amount, duration);

        config.veLogic.lock(address(config.rewardLogic), msg.sender, amount, duration);
    }

    function exitContribution(IERC20 token, uint amount) external nonReentrant returns (uint) {
        config.revenueLogic.claim(token, msg.sender, msg.sender, amount);

        return config.rewardLogic.exit(token, msg.sender, amount);
    }

    function claimEmission(IERC20 token, address receiver, uint amount) external nonReentrant returns (uint) {
        return config.rewardLogic.claimEmission(token, msg.sender, receiver, amount);
    }

    /// @notice Locks tokens, granting them voting power.
    /// @dev Emits a VotingEscrowLogic__Lock event on successful lock.
    /// @param amount The amount of tokens to be locked.
    /// @param duration The duration for which the tokens are to be locked.
    function lock(uint amount, uint duration) external nonReentrant {
        config.veLogic.lock(msg.sender, msg.sender, amount, duration);
    }

    /// @notice Allows a user to vest their tokens.
    /// @dev This function calls the `vest` function on the VotingEscrow contract, vesting the specified amount of
    /// tokens for the caller.
    /// @param amount The amount of tokens to be vested by the caller.
    function vestTokens(uint amount, address receiver) public nonReentrant {
        config.veLogic.vest(msg.sender, receiver, amount);
    }

    /// @notice Allows a user to claim vested tokens on behalf of another user.
    /// @dev This function calls the `claim` function on the VotingEscrow contract, allowing the caller to claim tokens
    /// on behalf of the specified
    /// user.
    /// @param receiver The address where the claimed tokens should be sent.
    /// @param amount The amount of tokens to claim.
    function veClaim(address receiver, uint amount) public nonReentrant {
        config.veLogic.claim(msg.sender, receiver, amount);
    }

    function buyback(IERC20 token, address receiver, uint amount) external nonReentrant {
        // config.revenueLogic.buyback(config.distributorBankStore, msg.sender, receiver, token, amount);
    }

    // governance

    function setConfig(Config memory _config) public auth {
        config = _config;

        logEvent("setConfig()", abi.encode(_config));
    }

    // internal

    error PuppetRouter__InvalidPuppet();
    error PuppetRouter__InvalidAllowance();
}
