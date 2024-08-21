// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {IGmxReferralStorage} from "../position/interface/IGmxReferralStorage.sol";

import {CoreContract} from "../utils/CoreContract.sol";
import {EventEmitter} from "../utils/EventEmitter.sol";
import {Precision} from "../utils/Precision.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {IERC20Mintable} from "../utils/interfaces/IERC20Mintable.sol";

import {RevenueStore} from "./store/RevenueStore.sol";
import {RewardStore} from "./store/RewardStore.sol";

import {PuppetVoteToken} from "./PuppetVoteToken.sol";
import {VotingEscrowLogic} from "./VotingEscrowLogic.sol";

/// @title Reward Logic
/// @notice Manages the distribution of rewards within the protocol, including locking mechanisms and bonus multipliers
/// for token holders.
/// @dev This contract handles the logic for reward emissions, locking tokens for voting power, and distributing rewards
/// to token holders.
/// It integrates with VotingEscrow for locking mechanisms, PuppetToken for minting rewards, RewardStore for tracking
/// reward accruals, and
/// RevenueStore for managing revenue balances.
contract RewardLogic is CoreContract {
    /// @notice Emitted when the configuration for the RewardLogic is set.
    /// @param timestamp The timestamp when the configuration was set.
    /// @param config The configuration settings that were applied.
    event RewardLogic__SetConfig(uint timestamp, Config config);

    /// @notice Struct to hold configuration parameters.
    struct Config {
        uint baselineEmissionRate;
        uint optionLockTokensBonusMultiplier;
        uint lockLiquidTokensBonusMultiplier;
        uint distributionTimeframe;
    }

    /// @notice The configuration parameters for the RewardLogic.
    Config public config;

    /// @notice The VotingEscrowLogic contract used for locking tokens.
    VotingEscrowLogic public immutable votingEscrow;

    /// @notice The contract used for minting rewards.
    IERC20Mintable public immutable mintToken;

    /// @notice The RewardStore contract used for tracking reward accruals.
    RewardStore public immutable store;

    /// @notice The RevenueStore contract used for managing revenue balances.
    RevenueStore public immutable revenueStore;

    /// @notice The PuppetVoteToken contract used for voting power.
    PuppetVoteToken public immutable vToken;

    function getClaimableEmission(IERC20 token, address user) public view returns (uint) {
        uint pendingEmission = getPendingEmission(token);
        uint rewardPerTokenCursor = store.getTokenEmissionRewardPerTokenCursor(token)
            + Precision.toFactor(pendingEmission, vToken.totalSupply());

        RewardStore.UserEmissionCursor memory userCursor = store.getUserEmissionReward(token, user);

        return userCursor.accruedReward
            + getUserPendingReward(rewardPerTokenCursor, userCursor.rewardPerToken, vToken.balanceOf(user));
    }

    constructor(
        IAuthority _authority,
        EventEmitter _eventEmitter,
        VotingEscrowLogic _votingEscrow,
        IERC20Mintable _mintToken,
        RewardStore _store,
        RevenueStore _revenueStore,
        Config memory _config
    ) CoreContract("RewardLogic", "1", _authority, _eventEmitter) {
        votingEscrow = _votingEscrow;
        store = _store;
        revenueStore = _revenueStore;
        mintToken = _mintToken;

        _setConfig(_config);
    }

    /// @notice Locks tokens to participate in reward distribution and increases voting power in the VotingEscrow.
    /// @dev Mints reward tokens based on the user's contribution balance and the specified duration, then locks these
    /// tokens.
    /// Emits a `RewardLogic__Lock` event upon successful locking of tokens.
    /// @param revenueToken The ERC20 token to be locked.
    /// @param duration The duration for which the tokens should be locked.
    /// @return rewardInToken The amount of reward tokens minted and locked for the user.
    function lock(IERC20 revenueToken, uint duration, address user) external auth returns (uint) {
        uint contributionBalance = revenueStore.getUserContributionBalance(revenueToken, user);

        if (contributionBalance > 0) revert RewardLogic__AmountExceedsContribution();

        uint tokenPerContributionCursor = revenueStore.getTokenPerContributionCursor(revenueToken);

        RewardStore.UserEmissionCursor memory userEmissionCursor = store.getUserEmissionReward(revenueToken, user);

        userEmissionCursor.rewardPerToken = distributeEmission(revenueToken);
        userEmissionCursor.accruedReward = getUserPendingReward(
            tokenPerContributionCursor, //
            userEmissionCursor.rewardPerToken,
            vToken.balanceOf(user)
        );

        uint rewardInToken = Precision.applyFactor(config.baselineEmissionRate, userEmissionCursor.accruedReward);

        store.setUserEmissionReward(revenueToken, user, userEmissionCursor);
        revenueStore.setUserContributionBalance(revenueToken, user, 0);
        revenueStore.setUserTokenPerContributionCursor(revenueToken, user, tokenPerContributionCursor);

        mintToken.mint(address(this), rewardInToken);
        votingEscrow.lock(address(this), user, rewardInToken, duration);

        eventEmitter.log(
            "RewardLogic__Lock",
            abi.encode(revenueToken, config.baselineEmissionRate, user, rewardInToken, duration, rewardInToken)
        );

        return rewardInToken;
    }

    /// @notice Allows a user to exit their locked position and claim rewards.
    /// @dev This function calculates the user's pending reward based on the baseline emission rate and their
    /// contribution balance.
    /// It then resets the user's contribution balance and updates the token per contribution cursor for the user.
    /// Finally, it mints the reward tokens to the contract itself and emits an event.
    /// @param revenueToken The ERC20 token that the user is exiting from.
    function exit(IERC20 revenueToken, address user) external auth {
        uint contributionBalance = revenueStore.getUserContributionBalance(revenueToken, user);

        if (contributionBalance > 0) revert RewardLogic__AmountExceedsContribution();

        uint tokenPerContributionCursor = revenueStore.getTokenPerContributionCursor(revenueToken);
        uint rewardInToken = Precision.applyFactor(
            config.baselineEmissionRate,
            getUserPendingReward(
                tokenPerContributionCursor,
                revenueStore.getUserTokenPerContributionCursor(revenueToken, user),
                contributionBalance
            )
        );

        revenueStore.setUserContributionBalance(revenueToken, user, 0);
        revenueStore.setUserTokenPerContributionCursor(revenueToken, user, tokenPerContributionCursor);
        mintToken.mint(address(this), rewardInToken);

        eventEmitter.log(
            "RewardLogic__Exit", abi.encode(revenueToken, config.baselineEmissionRate, user, rewardInToken)
        );
    }

    /// @notice Claims emission rewards for the caller and sends them to the specified receiver.
    /// @dev Calculates the claimable rewards for the caller based on the current reward cursor and the user's balance
    /// in the VotingEscrow contract.
    /// If the reward is non-zero, it updates the user's emission cursor, sets their accrued reward to zero, and
    /// transfers the reward to the receiver.
    /// @param revenueToken The ERC20 token for which rewards are being claimed.
    /// @param receiver The address where the claimed rewards should be sent.
    /// @return reward The amount of rewards claimed.
    function claimEmission(IERC20 revenueToken, address user, address receiver) public auth returns (uint) {
        uint nextRewardPerTokenCursor = distributeEmission(revenueToken);

        RewardStore.UserEmissionCursor memory userCursor = store.getUserEmissionReward(revenueToken, user);

        uint reward = userCursor.accruedReward
            + getUserPendingReward(
                nextRewardPerTokenCursor, //
                userCursor.rewardPerToken,
                vToken.balanceOf(user)
            );

        if (reward == 0) revert RewardLogic__NoClaimableAmount();

        userCursor.accruedReward = 0;
        userCursor.rewardPerToken = nextRewardPerTokenCursor;

        store.setUserEmissionReward(revenueToken, user, userCursor);
        revenueStore.transferOut(revenueToken, receiver, reward);

        eventEmitter.log("RewardLogic__Claim", abi.encode(user, receiver, nextRewardPerTokenCursor, reward));

        return reward;
    }

    // https://github.com/gmx-io/gmx-synthetics/blob/main/contracts/mock/ReferralStorage.sol#L127
    function transferReferralOwnership(
        IGmxReferralStorage _referralStorage,
        bytes32 _code,
        address _newOwner
    ) external auth {
        _referralStorage.setCodeOwner(_code, _newOwner);
    }

    // internal

    function distributeEmission(IERC20 revenueToken) internal returns (uint) {
        uint timeElapsed = block.timestamp - store.getTokenEmissionTimestamp(revenueToken);
        uint tokenBalance = revenueStore.getTokenBalance(revenueToken);
        uint rate = store.getTokenEmissionRate(revenueToken);
        uint nextRate = tokenBalance / config.distributionTimeframe;

        if (timeElapsed > config.distributionTimeframe) {
            store.setTokenEmissionRate(revenueToken, 0);
        } else if (nextRate > rate) {
            rate = nextRate;
            store.setTokenEmissionRate(revenueToken, nextRate);
        }

        store.setTokenEmissionTimestamp(revenueToken, block.timestamp);

        uint emission = Math.min(timeElapsed * rate, tokenBalance);

        if (emission == 0 || tokenBalance == 0) {
            return store.getTokenEmissionRewardPerTokenCursor(revenueToken);
        }

        uint supply = vToken.totalSupply();
        uint rewardPerToken =
            store.increaseTokenEmissionRewardPerTokenCursor(revenueToken, Precision.toFactor(emission, supply));

        eventEmitter.log(
            "RewardLogic__Distribute", abi.encode(revenueToken, config.distributionTimeframe, supply, rewardPerToken)
        );

        return rewardPerToken;
    }

    function getPendingEmission(IERC20 revenueToken) internal view returns (uint) {
        uint emissionBalance = revenueStore.getTokenBalance(revenueToken);
        uint lastTimestamp = store.getTokenEmissionTimestamp(revenueToken);
        uint rate = store.getTokenEmissionRate(revenueToken);

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

    // governance

    function setConfig(Config memory _config) external auth {
        _setConfig(_config);
    }

    function _setConfig(Config memory _config) internal {
        config = _config;

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
