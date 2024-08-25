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

import {RewardStore} from "./store/RewardStore.sol";

/// @title Reward Logic
/// @notice Manages the distribution of rewards within the protocol, including locking mechanisms and bonus multipliers
/// for token holders.
/// @dev This contract handles the logic for reward emissions, locking tokens for voting power, and distributing rewards
/// to token holders.
/// It integrates with VotingEscrow for locking mechanisms, PuppetToken for minting rewards, RewardStore for tracking
/// reward accruals, and
/// RevenueStore for managing revenue balances
contract RewardLogic is CoreContract {
    /// @notice Struct to hold configuration parameters.
    struct Config {
        uint baselineEmissionRate;
        uint optionLockTokensBonusMultiplier;
        uint lockLiquidTokensBonusMultiplier;
        uint distributionTimeframe;
    }

    /// @notice The configuration parameters for the RewardLogic
    Config public config;

    /// @notice The contract used for minting rewards.
    IERC20Mintable public immutable rewardToken;

    /// @notice The RewardStore contract used for tracking reward accruals
    RewardStore public immutable store;

    // /// @notice The RevenueStore contract used for managing revenue balances
    // RevenueStore public immutable revenueStore;

    /// @notice The token contract used for voting power
    IERC20 public immutable vToken;

    function getClaimableEmission(IERC20 token, address user) public view returns (uint) {
        uint userBalance = vToken.balanceOf(user);
        RewardStore.UserEmissionCursor memory userCursor = store.getUserEmissionReward(token, user);

        if (userBalance == 0) {
            return userCursor.accruedReward;
        }

        uint pendingEmission = getPendingEmission(token);
        uint rewardPerTokenCursor = store.getTokenEmissionRewardPerTokenCursor(token)
            + Precision.toFactor(pendingEmission, vToken.totalSupply());

        return userCursor.accruedReward
            + getUserPendingReward(rewardPerTokenCursor, userCursor.rewardPerToken, vToken.balanceOf(user));
    }

    constructor(
        IAuthority _authority,
        EventEmitter _eventEmitter,
        IERC20Mintable _mintToken,
        RewardStore _store,
        Config memory _config
    ) CoreContract("RewardLogic", "1", _authority, _eventEmitter) {
        store = _store;
        // revenueStore = _revenueStore;
        rewardToken = _mintToken;

        setConfig(_config);
    }

    /// @notice Locks tokens to participate in reward distribution and increases voting power in the VotingEscrow.
    /// @dev Mints reward tokens based on the user's contribution balance and the specified duration, then locks these
    /// tokens
    /// Emits a `RewardLogic__Lock` event upon successful locking of tokens
    /// @param token The ERC20 token to be locked
    /// @param duration The duration for which the tokens should be locked
    /// @param user The address of the user locking the tokens
    /// @return rewardInToken The amount of reward tokens minted and locked for the user
    function lock(IERC20 token, address user, uint contribution, uint duration) external auth returns (uint) {
        uint nextRewardPerTokenCursor = distribute(token);

        uint reward = Precision.applyFactor(config.baselineEmissionRate, contribution);

        rewardToken.mint(address(this), reward);

        logEvent("lock()", abi.encode(token, user, duration, reward));

        return reward;
    }

    /// @notice Exits a user from a revenue position, minting reward tokens based on their contribution balance.
    /// @dev Calculates the reward tokens based on the user's contribution balance and the token per contribution
    /// cursor. It then mints these tokens and transfers them to a vesting contract.
    /// @param token The token contributed by the user for which rewards are being minted.
    /// @param user The address of the user exiting the position.
    function exit(IERC20 token, address user, uint contribution) external auth returns (uint) {
        uint reward = Precision.applyFactor(config.baselineEmissionRate, contribution);

        rewardToken.mint(address(this), reward);

        logEvent("exit()", abi.encode(token, user, contribution, reward));

        return reward;
    }

    /// @notice Claims emission rewards for the caller and sends them to the specified receiver.
    /// @dev Calculates the claimable rewards for the caller based on the current reward cursor and the user's balance
    /// in the VotingEscrow contract.
    /// If the reward is non-zero, it updates the user's emission cursor, sets their accrued reward to zero, and
    /// transfers the reward to the receiver.
    /// @param contributionToken The ERC20 token for which rewards are being claimed.
    /// @param receiver The address where the claimed rewards should be sent.
    /// @return reward The amount of rewards claimed.
    function claimEmission(
        IERC20 contributionToken,
        address user,
        address receiver,
        uint amount
    ) public auth returns (uint) {
        uint nextRewardPerTokenCursor = distribute(contributionToken);

        RewardStore.UserEmissionCursor memory userCursor = store.getUserEmissionReward(contributionToken, user);

        uint reward = userCursor.accruedReward
            + getUserPendingReward(
                nextRewardPerTokenCursor, //
                userCursor.rewardPerToken,
                vToken.balanceOf(user)
            );

        if (reward == 0) revert RewardLogic__NoClaimableAmount();

        userCursor.rewardPerToken = nextRewardPerTokenCursor;
        userCursor.accruedReward -= amount;

        store.setUserEmissionReward(contributionToken, user, userCursor);
        store.transferOut(rewardToken, receiver, amount);

        logEvent("claimEmission()", abi.encode(user, receiver, amount));

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

    // integration

    function userDistribute(
        IERC20 token,
        address user
    ) external returns (RewardStore.UserEmissionCursor memory userCursor) {
        uint nextRewardPerTokenCursor = distribute(token);

        userCursor = store.getUserEmissionReward(token, user);

        userCursor.rewardPerToken = nextRewardPerTokenCursor;
        userCursor.accruedReward = userCursor.accruedReward
            + getUserPendingReward(
                nextRewardPerTokenCursor, //
                userCursor.rewardPerToken,
                vToken.balanceOf(user)
            );
    }

    function distribute(IERC20 token) internal returns (uint) {
        uint timeElapsed = block.timestamp - store.getTokenEmissionTimestamp(token);
        uint tokenBalance = store.getTokenBalance(token);
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

        uint supply = vToken.totalSupply();
        uint rewardPerToken = store.increaseTokenEmissionRewardPerTokenCursor(
            token, //
            Precision.toFactor(emission, supply)
        );

        logEvent("distribute()", abi.encode(token, rewardPerToken, emission));

        return rewardPerToken;
    }

    // internal

    function getPendingEmission(IERC20 revenueToken) internal view returns (uint) {
        uint emissionBalance = store.getTokenBalance(revenueToken);
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

    function setConfig(Config memory _config) public auth {
        config = _config;

        logEvent("setConfig()", abi.encode(_config));
    }

    /// @notice Error emitted when the claimable amount is insufficient
    error RewardLogic__InssufficientClaimableAmount();
    /// @notice Error emitted when there is no claimable amount for a user
    error RewardLogic__NoClaimableAmount();
}
