// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {IGmxReferralStorage} from "../position/interface/IGmxReferralStorage.sol";

import {ReentrancyGuardTransient} from "../utils/ReentrancyGuardTransient.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {Permission} from "../utils/access/Permission.sol";
import {Precision} from "../utils/Precision.sol";

import {VotingEscrow, MAXTIME} from "./VotingEscrow.sol";
import {PuppetToken} from "./PuppetToken.sol";
import {RewardStore} from "./store/RewardStore.sol";
import {RevenueStore} from "src/tokenomics/store/RevenueStore.sol";

/// @title RewardLogic
/// @notice Manages the distribution of rewards within the protocol, including locking mechanisms and bonus multipliers for token holders.
/// @dev This contract handles the logic for reward emissions, locking tokens for voting power, and distributing rewards to token holders.
/// It integrates with VotingEscrow for locking mechanisms, PuppetToken for minting rewards, RewardStore for tracking reward accruals, and
/// RevenueStore for managing revenue balances.
contract RewardLogic is Permission, EIP712, ReentrancyGuardTransient {
    /// @notice Emitted when the configuration for the RewardLogic is set.
    /// @param timestamp The timestamp when the configuration was set.
    /// @param callConfig The configuration settings that were applied.
    event RewardLogic__SetConfig(uint timestamp, Config callConfig);

    /// @notice Emitted when a user locks tokens to receive rewards.
    /// @param token The ERC20 token that is being locked.
    /// @param baselineEmissionRate The baseline emission rate used for calculating rewards.
    /// @param user The address of the user who is locking tokens.
    /// @param accruedReward The amount of rewards that have been accrued by the user.
    /// @param duration The duration for which the tokens are locked.
    /// @param rewardInToken The amount of rewards in the form of the locked token.
    event RewardLogic__Lock(IERC20 token, uint baselineEmissionRate, address user, uint accruedReward, uint duration, uint rewardInToken);

    /// @notice Emitted when a user exits their locked position and claims rewards.
    /// @param token The ERC20 token that was locked.
    /// @param baselineEmissionRate The baseline emission rate used for calculating rewards.
    /// @param user The address of the user who is exiting.
    /// @param rewardInToken The amount of rewards in the form of the locked token.
    event RewardLogic__Exit(IERC20 token, uint baselineEmissionRate, address user, uint rewardInToken);

    /// @notice Emitted when a user claims their accrued emission rewards.
    /// @param user The address of the user claiming rewards.
    /// @param receiver The address where the claimed rewards are sent.
    /// @param rewardPerTokenCursor The updated reward per token cursor after the claim.
    /// @param amount The amount of rewards claimed.
    event RewardLogic__Claim(address user, address receiver, uint rewardPerTokenCursor, uint amount);

    /// @notice Emitted when rewards are distributed to users.
    /// @param token The ERC20 token for which rewards are being distributed.
    /// @param distributionTimeframe The timeframe over which the rewards are distributed.
    /// @param supply The total supply of locked tokens.
    /// @param nextRewardPerTokenCursor The updated reward per token cursor after distribution.
    event RewardLogic__Distribute(IERC20 token, uint distributionTimeframe, uint supply, uint nextRewardPerTokenCursor);

    /// @notice Emitted when a buyback is performed.
    /// @param buyer The address of the buyer performing the buyback.
    /// @param thresholdAmount The threshold amount for the buyback.
    /// @param token The ERC20 token being bought back.
    /// @param rewardPerContributionCursor The reward per contribution cursor at the time of the buyback.
    /// @param totalFee The total fee associated with the buyback.
    event RewardLogic__Buyback(address buyer, uint thresholdAmount, IERC20 token, uint rewardPerContributionCursor, uint totalFee);

    /// @notice Struct to hold configuration parameters.
    struct Config {
        uint baselineEmissionRate;
        uint optionLockTokensBonusMultiplier;
        uint lockLiquidTokensBonusMultiplier;
        uint distributionTimeframe;
    }

    /// @notice The configuration parameters for the RewardLogic.
    Config public config;

    /// @notice The VotingEscrow contract used for locking tokens.
    VotingEscrow public immutable votingEscrow;

    /// @notice The PuppetToken contract used for minting rewards.
    PuppetToken public immutable puppetToken;

    /// @notice The RewardStore contract used for tracking reward accruals.
    RewardStore public immutable store;

    /// @notice The RevenueStore contract used for managing revenue balances.
    RevenueStore public immutable revenueStore;

    function getClaimableEmission(IERC20 token, address user) public view returns (uint) {
        uint pendingEmission = getPendingEmission(token);
        uint rewardPerTokenCursor =
            store.getTokenEmissionRewardPerTokenCursor(token) + Precision.toFactor(pendingEmission, votingEscrow.totalSupply());

        RewardStore.UserEmissionCursor memory userCursor = store.getUserEmissionReward(token, user);

        return userCursor.accruedReward + getUserPendingReward(rewardPerTokenCursor, userCursor.rewardPerToken, votingEscrow.balanceOf(user));
    }

    function getBonusReward(uint durationBonusMultiplier, uint reward, uint duration) public view returns (uint) {
        uint baselineAmount = Precision.applyFactor(config.baselineEmissionRate, reward);
        uint durationMultiplier = getDurationBonusMultiplier(durationBonusMultiplier, duration);
        return Precision.applyFactor(durationMultiplier, baselineAmount);
    }

    constructor(
        IAuthority _authority,
        VotingEscrow _votingEscrow,
        PuppetToken _puppetToken,
        RewardStore _store,
        RevenueStore _revenueStore,
        Config memory _callConfig
    ) Permission(_authority) EIP712("Reward Logic", "1") {
        votingEscrow = _votingEscrow;
        store = _store;
        revenueStore = _revenueStore;
        puppetToken = _puppetToken;

        _setConfig(_callConfig);
    }

    /// @notice Locks tokens to participate in reward distribution and increases voting power in the VotingEscrow.
    /// @dev Mints reward tokens based on the user's contribution balance and the specified duration, then locks these tokens.
    /// Emits a `RewardLogic__Lock` event upon successful locking of tokens.
    /// @param token The ERC20 token to be locked.
    /// @param duration The duration for which the tokens should be locked.
    /// @return rewardInToken The amount of reward tokens minted and locked for the user.
    function lock(IERC20 token, uint duration) public nonReentrant returns (uint) {
        uint contributionBalance = revenueStore.getUserContributionBalance(token, msg.sender);

        if (contributionBalance > 0) revert RewardLogic__AmountExceedsContribution();

        uint tokenPerContributionCursor = revenueStore.getTokenPerContributionCursor(token);
        uint rewardInToken = getBonusReward(
            getUserPendingReward(tokenPerContributionCursor, revenueStore.getUserTokenPerContributionCursor(token, msg.sender), contributionBalance),
            config.optionLockTokensBonusMultiplier,
            duration
        );

        RewardStore.UserEmissionCursor memory userEmissionCursor = store.getUserEmissionReward(token, msg.sender);

        userEmissionCursor.rewardPerToken = distributeEmission(token);
        userEmissionCursor.accruedReward = getUserPendingReward(
            tokenPerContributionCursor, //
            userEmissionCursor.rewardPerToken,
            votingEscrow.balanceOf(msg.sender)
        );

        store.setUserEmissionReward(token, msg.sender, userEmissionCursor);
        revenueStore.setUserContributionBalance(token, msg.sender, 0);
        revenueStore.setUserTokenPerContributionCursor(token, msg.sender, tokenPerContributionCursor);

        puppetToken.mint(address(this), rewardInToken);
        votingEscrow.lock(address(this), msg.sender, rewardInToken, duration);

        emit RewardLogic__Lock(token, config.baselineEmissionRate, msg.sender, rewardInToken, duration, rewardInToken);
    }

    /// @notice Allows a user to exit their locked position and claim rewards.
    /// @dev This function calculates the user's pending reward based on the baseline emission rate and their contribution balance.
    /// It then resets the user's contribution balance and updates the token per contribution cursor for the user.
    /// Finally, it mints the reward tokens to the contract itself and emits an event.
    /// @param token The ERC20 token that the user is exiting from.
    function exit(IERC20 token) external nonReentrant {
        uint contributionBalance = revenueStore.getUserContributionBalance(token, msg.sender);

        if (contributionBalance > 0) revert RewardLogic__AmountExceedsContribution();

        uint tokenPerContributionCursor = revenueStore.getTokenPerContributionCursor(token);
        uint rewardInToken = Precision.applyFactor(
            config.baselineEmissionRate,
            getUserPendingReward(tokenPerContributionCursor, revenueStore.getUserTokenPerContributionCursor(token, msg.sender), contributionBalance)
        );

        revenueStore.setUserContributionBalance(token, msg.sender, 0);
        revenueStore.setUserTokenPerContributionCursor(token, msg.sender, tokenPerContributionCursor);
        puppetToken.mint(address(this), rewardInToken);

        emit RewardLogic__Exit(token, config.baselineEmissionRate, msg.sender, rewardInToken);
    }

    /// @notice Locks liquid tokens for a user for a given duration, applying a bonus multiplier.
    /// @dev Mints the specified amount of tokens to this contract and then locks them in the VotingEscrow contract.
    /// The reward after applying the bonus multiplier is returned but not minted or distributed.
    /// @param user The address of the user for whom the tokens will be locked.
    /// @param unlockDuration The duration in seconds for which the tokens will be locked.
    /// @param amount The amount of tokens to lock.
    /// @return rewardAfterMultiplier The amount of reward after applying the lockLiquidTokensBonusMultiplier.
    function lockToken(address user, uint unlockDuration, uint amount) external nonReentrant returns (uint) {
        uint rewardAfterMultiplier = getBonusReward(config.lockLiquidTokensBonusMultiplier, amount, unlockDuration);

        puppetToken.mint(address(this), amount);
        votingEscrow.lock(user, user, amount, unlockDuration);

        return rewardAfterMultiplier;
    }

    /// @notice Allows a user to vest their tokens.
    /// @dev This function calls the `vest` function on the VotingEscrow contract, vesting the specified amount of tokens for the caller.
    /// @param amount The amount of tokens to be vested by the caller.
    function vestTokens(uint amount) public nonReentrant {
        votingEscrow.vest(msg.sender, msg.sender, amount);
    }

    /// @notice Allows a user to claim vested tokens on behalf of another user.
    /// @dev This function calls the `claim` function on the VotingEscrow contract, allowing the caller to claim tokens on behalf of the specified
    /// user.
    /// @param receiver The address where the claimed tokens should be sent.
    /// @param amount The amount of tokens to claim.
    function veClaim(address receiver, uint amount) public nonReentrant {
        votingEscrow.claim(msg.sender, receiver, amount);
    }

    /// @notice Claims emission rewards for the caller and sends them to the specified receiver.
    /// @dev Calculates the claimable rewards for the caller based on the current reward cursor and the user's balance in the VotingEscrow contract.
    /// If the reward is non-zero, it updates the user's emission cursor, sets their accrued reward to zero, and transfers the reward to the receiver.
    /// @param token The ERC20 token for which rewards are being claimed.
    /// @param receiver The address where the claimed rewards should be sent.
    /// @return reward The amount of rewards claimed.
    function claimEmission(IERC20 token, address receiver) public nonReentrant returns (uint) {
        uint nextRewardPerTokenCursor = distributeEmission(token);

        RewardStore.UserEmissionCursor memory userCursor = store.getUserEmissionReward(token, msg.sender);

        uint reward = userCursor.accruedReward
            + getUserPendingReward(
                nextRewardPerTokenCursor, //
                userCursor.rewardPerToken,
                votingEscrow.balanceOf(msg.sender)
            );

        if (reward == 0) revert RewardLogic__NoClaimableAmount();

        userCursor.accruedReward = 0;
        userCursor.rewardPerToken = nextRewardPerTokenCursor;

        store.setUserEmissionReward(token, msg.sender, userCursor);
        revenueStore.transferOut(token, receiver, reward);

        emit RewardLogic__Claim(msg.sender, receiver, nextRewardPerTokenCursor, reward);

        return reward;
    }

    /// @notice Distributes emission rewards for a given token based on the time elapsed and the token's emission rate.
    /// @dev Calculates the emission rewards since the last distribution, updates the token's emission rate if necessary, and increases the reward per
    /// token cursor.
    /// If the emission or token balance is zero, it returns the current reward per token cursor without making changes.
    /// @param token The ERC20 token for which emissions are being distributed.
    /// @return rewardPerToken The updated reward per token cursor after distribution.
    function distributeEmission(IERC20 token) public nonReentrant returns (uint) {
        uint timeElapsed = block.timestamp - store.getTokenEmissionTimestamp(token);
        uint tokenBalance = revenueStore.getTokenBalance(token);
        uint rate = store.getTokenEmissionRate(token);
        uint nextRate = tokenBalance / config.distributionTimeframe;

        if (timeElapsed > config.distributionTimeframe) {
            store.setTokenEmissionRate(token, 0);
        } else if (nextRate > rate) {
            rate = nextRate;
            store.setTokenEmissionRate(token, nextRate);
        }

        store.setTokenEmissionTimestamp(token, block.timestamp);

        uint emission = Math.min(timeElapsed * rate, tokenBalance);

        if (emission == 0 || tokenBalance == 0) {
            return store.getTokenEmissionRewardPerTokenCursor(token);
        }

        uint supply = votingEscrow.totalSupply();
        uint rewardPerToken = store.increaseTokenEmissionRewardPerTokenCursor(token, Precision.toFactor(emission, supply));

        emit RewardLogic__Distribute(token, config.distributionTimeframe, supply, rewardPerToken);

        return rewardPerToken;
    }

    // governance

    function setConfig(Config memory _callConfig) external auth {
        _setConfig(_callConfig);
    }

    // https://github.com/gmx-io/gmx-synthetics/blob/main/contracts/mock/ReferralStorage.sol#L127
    function transferReferralOwnership(IGmxReferralStorage _referralStorage, bytes32 _code, address _newOwner) external auth {
        _referralStorage.setCodeOwner(_code, _newOwner);
    }

    // internal

    function getDurationBonusMultiplier(uint durationBonusMultiplier, uint duration) internal pure returns (uint) {
        uint durationMultiplier = Precision.applyFactor(durationBonusMultiplier, MAXTIME);

        return Precision.toFactor(duration, durationMultiplier);
    }

    function getPendingEmission(IERC20 token) internal view returns (uint) {
        uint emissionBalance = revenueStore.getTokenBalance(token);
        uint lastTimestamp = store.getTokenEmissionTimestamp(token);
        uint rate = store.getTokenEmissionRate(token);

        uint nextRate = emissionBalance / config.distributionTimeframe;
        uint timeElapsed = block.timestamp - lastTimestamp;

        if (nextRate > rate) {
            rate = nextRate;
        }

        return Math.min(timeElapsed * nextRate, emissionBalance);
    }

    function getUserPendingReward(uint cursor, uint userCursor, uint userBalance) internal pure returns (uint) {
        return userBalance * (cursor - userCursor) / Precision.FLOAT_PRECISION;
    }

    function _setConfig(Config memory _callConfig) internal {
        config = _callConfig;

        emit RewardLogic__SetConfig(block.timestamp, config);
    }

    /// @notice Error emitted when there is no claimable amount for a user.
    error RewardLogic__NoClaimableAmount();
    /// @notice Error emitted when the token price is unacceptable for an operation.
    error RewardLogic__UnacceptableTokenPrice(uint tokenPrice);
    /// @notice Error emitted when the claim price is invalid.
    error RewardLogic__InvalidClaimPrice();
    /// @notice Error emitted when the duration for an operation is invalid.
    error RewardLogic__InvalidDuration();
    /// @notice Error emitted when there is nothing to claim for a user.
    error RewardLogic__NotingToClaim();
    /// @notice Error emitted when the amount exceeds the user's contribution.
    error RewardLogic__AmountExceedsContribution();
    /// @notice Error emitted when the weight factors are invalid.
    error RewardLogic__InvalidWeightFactors();
}
