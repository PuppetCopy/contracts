// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {IGmxReferralStorage} from "../position/interface/IGmxReferralStorage.sol";
import {CoreContract} from "../utils/CoreContract.sol";
import {EventEmitter} from "../utils/EventEmitter.sol";
import {Precision} from "../utils/Precision.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {RewardStore} from "./store/RewardStore.sol";

/// @title RewardLogic
/// @notice Manages the distribution of rewards based VotingEscrow Voting Power for token holders.
/// @dev This contract handles the logic for reward emissions based on voting power RewardStore for tracking reward
/// tracking and accruals
contract RewardLogic is CoreContract {
    /// @notice Struct to hold configuration parameters.
    struct Config {
        uint distributionTimeframe;
    }

    /// @notice The configuration parameters for the RewardLogic
    Config public config;

    /// @notice The contract used for minting rewards.
    IERC20 public immutable rewardToken;

    /// @notice The RewardStore contract used for tracking reward accruals
    RewardStore public immutable store;

    /// @notice The token contract used for voting power
    IERC20 public immutable vToken;

    function getClaimable(address user) external view returns (uint) {
        uint cumulativeRewardPerContribution = store.cumulativeRewardPerToken();
        RewardStore.UserRewardCursor memory userCursor = getUserRewardCursor(user, cumulativeRewardPerContribution);

        uint rewardPerTokenCursor = cumulativeRewardPerContribution
            + Precision.toFactor(
                getPendingReward(), //
                vToken.totalSupply()
            );

        return userCursor.accruedReward
            + getUserPendingReward(
                rewardPerTokenCursor, //
                userCursor.rewardPerToken,
                vToken.balanceOf(user)
            );
    }

    constructor(
        IAuthority _authority,
        EventEmitter _eventEmitter,
        IERC20 _rewardToken,
        IERC20 _vToken,
        RewardStore _store,
        Config memory _config
    ) CoreContract("RewardLogic", "1", _authority, _eventEmitter) {
        rewardToken = _rewardToken;
        vToken = _vToken;
        store = _store;

        _setConfig(_config);
    }

    /// @notice Claims the accrued rewards for a user based on their voting power
    /// @param user The address of the user to claim the rewards for
    /// @param receiver The address to receive the claimed rewards
    /// @param amount The amount of rewards to claim
    function claim(address user, address receiver, uint amount) external auth {
        uint nextRewardPerTokenCursor = distribute();

        RewardStore.UserRewardCursor memory cursor = getUserRewardCursor(user, nextRewardPerTokenCursor);

        if (amount > cursor.accruedReward) revert RewardLogic__NoClaimableAmount();

        cursor.accruedReward -= amount;

        store.setUserRewardCursor(user, cursor);
        store.transferOut(rewardToken, receiver, amount);

        logEvent("claim()", abi.encode(user, receiver, amount));
    }

    function userDistribute(address user) external auth returns (RewardStore.UserRewardCursor memory cursor) {
        uint nextRewardPerTokenCursor = distribute();
        cursor = getUserRewardCursor(user, nextRewardPerTokenCursor);
        store.setUserRewardCursor(user, cursor);
    }

    // internal

    /// @notice Distributes the rewards to the users based on the current token emission rate and the time elapsed
    /// @return The updated cumulative reward per contribution state
    function distribute() internal returns (uint) {
        uint timeElapsed = block.timestamp - store.tokenRewardTimestamp();
        uint rewardBalance = store.getTokenBalance(rewardToken);
        uint rate = store.tokenRewardRate();
        uint nextRate = rewardBalance / config.distributionTimeframe;

        if (timeElapsed >= config.distributionTimeframe) {
            store.setTokenRewardRate(0);
        } else if (nextRate > rate) {
            rate = nextRate;
            store.setTokenRewardRate(nextRate);
        }

        store.setTokenRewardTimestamp(block.timestamp);

        uint emission = Math.min(timeElapsed * rate, rewardBalance);

        if (emission == 0 || rewardBalance == 0) {
            return store.cumulativeRewardPerToken();
        }

        uint supply = vToken.totalSupply();
        uint rewardPerToken = store.incrementCumulativePerContribution(Precision.toFactor(emission, supply));

        logEvent("distribute()", abi.encode(rewardPerToken, supply, emission));

        return rewardPerToken;
    }

    function getUserRewardCursor(
        address user,
        uint rewardPerTokenCursor
    ) internal view returns (RewardStore.UserRewardCursor memory cursor) {
        cursor = store.getUserRewardCursor(user);
        cursor.rewardPerToken = rewardPerTokenCursor;
        cursor.accruedReward = cursor.accruedReward
            + getUserPendingReward(rewardPerTokenCursor, cursor.rewardPerToken, vToken.balanceOf(user));

        return cursor;
    }

    function getPendingReward() internal view returns (uint) {
        uint timeElapsed = block.timestamp - store.tokenRewardTimestamp();
        uint rewardBalance = store.getTokenBalance(rewardToken);
        uint rate = store.tokenRewardRate();
        uint nextRate = rewardBalance / config.distributionTimeframe;

        if (nextRate > rate) {
            rate = nextRate;
        }

        return Math.min(timeElapsed * nextRate, rewardBalance);
    }

    function getUserPendingReward(uint cursor, uint userCursor, uint userBalance) internal pure returns (uint) {
        return userBalance * (cursor - userCursor) / Precision.FLOAT_PRECISION;
    }

    // governance

    // https://github.com/gmx-io/gmx-synthetics/blob/main/contracts/mock/ReferralStorage.sol#L127
    function transferReferralOwnership(
        IGmxReferralStorage _referralStorage,
        bytes32 _code,
        address _newOwner
    ) external auth {
        _referralStorage.setCodeOwner(_code, _newOwner);
    }
    /// @notice Set the mint rate limit for the token.
    /// @param _config The new rate limit configuration.

    function setConfig(Config calldata _config) external auth {
        _setConfig(_config);
    }

    /// @dev Internal function to set the configuration.
    /// @param _config The configuration to set.
    function _setConfig(Config memory _config) internal {
        config = _config;
        logEvent("setConfig()", abi.encode(_config));
    }

    /// @notice Error emitted when there is no claimable amount for a user
    error RewardLogic__NoClaimableAmount();
}
