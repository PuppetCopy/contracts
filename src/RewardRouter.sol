// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Multicall} from "@openzeppelin/contracts/utils/Multicall.sol";

import {ContributeLogic} from "./tokenomics/ContributeLogic.sol";
import {RewardLogic} from "./tokenomics/RewardLogic.sol";
import {VotingEscrowLogic} from "./tokenomics/VotingEscrowLogic.sol";
import {CoreContract} from "./utils/CoreContract.sol";
import {EventEmitter} from "./utils/EventEmitter.sol";
import {ReentrancyGuardTransient} from "./utils/ReentrancyGuardTransient.sol";
import {Auth} from "./utils/access/Auth.sol";
import {IAuthority} from "./utils/interfaces/IAuthority.sol";

contract RewardRouter is CoreContract, ReentrancyGuardTransient, Multicall {
    struct Config {
        RewardLogic rewardLogic;
        VotingEscrowLogic veLogic;
        ContributeLogic contributeLogic;
    }

    Config config;

    constructor(
        IAuthority _authority,
        EventEmitter _eventEmitter,
        Config memory _config
    ) CoreContract("RewardRouter", "1", _authority, _eventEmitter) {
        _setConfig(_config);
    }

    /// @notice Executes the buyback of revenue tokens using the protocol's accumulated fees.
    /// @param token The address of the revenue token to be bought back.
    /// @param receiver The address that will receive the revenue token.
    /// @param amount The amount of revenue tokens to be bought back.
    function buyback(IERC20 token, address receiver, uint amount) external nonReentrant {
        config.rewardLogic.distribute();
        config.contributeLogic.buyback(token, msg.sender, receiver, amount);
    }

    /// @notice Claims the rewards for a specific token contribution.
    /// @param receiver The address where the claimed tokens should be sent.
    /// @param amount The amount of rewards to be claimed.
    /// @return The amount of rewards claimed.
    function claimContribution(
        IERC20[] calldata tokenList,
        address receiver,
        uint amount
    ) public nonReentrant returns (uint) {
        return config.contributeLogic.claim(tokenList, msg.sender, receiver, amount);
    }

    /// @notice Locks tokens, granting them voting power.
    /// @param amount The amount of tokens to be locked.
    /// @param duration The duration for which the tokens are to be locked.
    function lock(uint amount, uint duration) public nonReentrant {
        config.rewardLogic.userDistribute(msg.sender);
        config.veLogic.lock(msg.sender, msg.sender, amount, duration);
    }

    /// @notice Allows a user to vest their tokens.
    /// @param amount The amount of tokens to be vested by the caller.
    /// @param receiver The address where the vested tokens should be sent.
    function vest(uint amount, address receiver) public nonReentrant {
        config.rewardLogic.userDistribute(msg.sender);
        config.veLogic.vest(msg.sender, receiver, amount);
    }

    /// @notice Allows a user to claim vested tokens.
    /// @param receiver The address where the claimed tokens should be sent.
    /// @param amount The amount of tokens to claim.
    function claimEmission(address receiver, uint amount) public nonReentrant {
        config.rewardLogic.claim(msg.sender, receiver, amount);
    }

    /// @notice Allows a user to claim vested tokens on behalf of another user.
    /// @param receiver The address where the claimed tokens should be sent.
    /// @param amount The amount of tokens to claim.
    function claimVested(address receiver, uint amount) public nonReentrant {
        config.veLogic.claim(msg.sender, receiver, amount);
    }

    // governance

    /// @notice Set the mint rate limit for the token.
    /// @param _config The new rate limit configuration.
    function setConfig(Config calldata _config) external auth nonReentrant {
        _setConfig(_config);
    }

    /// @dev Internal function to set the configuration.
    /// @param _config The configuration to set.
    function _setConfig(Config memory _config) internal {
        config = _config;
        logEvent("setConfig", abi.encode(_config));
    }

    // internal

    error PuppetRouter__InvalidPuppet();
    error PuppetRouter__InvalidAllowance();
}
