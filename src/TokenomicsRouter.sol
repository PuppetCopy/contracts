// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ReentrancyGuardTransient} from "./utils/ReentrancyGuardTransient.sol";
import {Auth} from "./utils/access/Auth.sol";
import {IAuthority} from "./utils/interfaces/IAuthority.sol";

import {RewardLogic} from "./tokenomics/RewardLogic.sol";
import {VotingEscrowLogic} from "./tokenomics/VotingEscrowLogic.sol";

contract TokenomicsRouter is Auth, ReentrancyGuardTransient {
    event PuppetRouter__SetConfig(uint timestamp, Config config);

    struct Config {
        RewardLogic rewardLogic;
        VotingEscrowLogic veLogic;
    }

    Config config;

    constructor(IAuthority _authority, Config memory _config) Auth(_authority) {
        _setConfig(_config);
    }

    function lock(IERC20 token, uint duration) external nonReentrant returns (uint) {
        return config.rewardLogic.lock(token, duration, msg.sender);
    }

    function exit(IERC20 token) external nonReentrant {
        config.rewardLogic.exit(token, msg.sender);
    }

    function claimEmission(IERC20 token, address receiver) external nonReentrant returns (uint) {
        return config.rewardLogic.claimEmission(token, msg.sender, receiver);
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

    // governance

    function setConfig(Config memory _config) external auth {
        _setConfig(_config);
    }

    // internal

    function _setConfig(Config memory _config) internal {
        config = _config;

        emit PuppetRouter__SetConfig(block.timestamp, _config);
    }

    error PuppetRouter__InvalidPuppet();
    error PuppetRouter__InvalidAllowance();
}