// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {IGmxReferralStorage} from "../position/interface/IGmxReferralStorage.sol";
import {Error} from "../shared/Error.sol";
import {BankStore} from "../shared/store/BankStore.sol";
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
        BankStore distributionStore;
    }

    /// @notice The contract used for minting rewards.
    IERC20 public immutable rewardToken;

    /// @notice The token contract used for voting power
    IERC20 public immutable vToken;

    /// @notice The RewardStore contract used for tracking reward accruals
    RewardStore immutable store;

    /// @notice The configuration parameters for the RewardLogic
    Config public config;

    function getPendingEmission() public view returns (uint reward) {
        uint timeElapsed = block.timestamp - store.lastDistributionTimestamp();
        uint balance = config.distributionStore.getTokenBalance(rewardToken);

        reward = Math.min(balance * timeElapsed / config.distributionTimeframe, balance);
    }

    function getClaimable(
        address user
    ) external view returns (uint) {
        RewardStore.UserRewardCursor memory cursor = store.getUserRewardCursor(user);

        uint cumulativeRewardPerToken =
            store.cumulativeRewardPerToken() + Precision.toFactor(getPendingEmission(), vToken.totalSupply());

        return cursor.accruedReward
            + getPendingReward(cumulativeRewardPerToken, cursor.rewardPerToken, vToken.balanceOf(user));
    }

    constructor(
        IAuthority _authority,
        EventEmitter _eventEmitter,
        IERC20 _rewardToken,
        IERC20 _vToken,
        RewardStore _store
    ) CoreContract("RewardLogic", "1", _authority, _eventEmitter) {
        rewardToken = _rewardToken;
        vToken = _vToken;
        store = _store;
    }

    /// @notice Claims the accrued rewards for a user based on their voting power
    /// @param user The address of the user to claim the rewards for
    /// @param receiver The address to receive the claimed rewards
    /// @param amount The amount of rewards to claim
    function claim(address user, address receiver, uint amount) external auth {
        uint nextRewardPerTokenCursor = distribute();

        RewardStore.UserRewardCursor memory cursor = store.getUserRewardCursor(user);
        cursor.accruedReward +=
            getPendingReward(nextRewardPerTokenCursor, cursor.rewardPerToken, vToken.balanceOf(user));
        cursor.rewardPerToken = nextRewardPerTokenCursor;

        if (amount > cursor.accruedReward) revert Error.RewardLogic__NoClaimableAmount(cursor.accruedReward);

        cursor.accruedReward -= amount;

        store.setUserRewardCursor(user, cursor);
        store.transferOut(rewardToken, receiver, amount);

        logEvent("Claim", abi.encode(user, receiver, amount));
    }

    /// @notice Distributes the rewards to the users based on the current token emission rate and the time elapsed
    /// @param user The address of the user to distribute the rewards for
    function userDistribute(
        address user
    ) public auth {
        uint nextRewardPerTokenCursor = distribute();
        uint userVBalance = vToken.balanceOf(user);

        RewardStore.UserRewardCursor memory cursor = store.getUserRewardCursor(user);
        cursor.accruedReward += getPendingReward(nextRewardPerTokenCursor, cursor.rewardPerToken, userVBalance);
        cursor.rewardPerToken = nextRewardPerTokenCursor;

        store.setUserRewardCursor(user, cursor);
    }

    /// @notice Distributes the rewards to the users based on the current token emission rate and the time elapsed
    /// @return The updated cumulative reward per contribution state
    function distribute() public auth returns (uint) {
        uint emission = getPendingEmission();
        uint supply = vToken.totalSupply();

        store.setLastDistributionTimestamp(block.timestamp);

        if (emission == 0 || supply == 0) return store.cumulativeRewardPerToken();

        store.interTransferIn(rewardToken, config.distributionStore, emission);

        uint rewardPerToken = store.incrementCumulativePerContribution(Precision.toFactor(emission, supply));

        logEvent("Distribute", abi.encode(rewardPerToken, supply, emission));

        return rewardPerToken;
    }

    // internal

    function getPendingReward(
        uint cumulativeRewardPerToken,
        uint userCursor,
        uint userBalance
    ) internal pure returns (uint) {
        return userBalance * (cumulativeRewardPerToken - userCursor) / Precision.FLOAT_PRECISION;
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

    function setConfig(
        Config calldata _config
    ) external auth {
        config = _config;
        logEvent("SetConfig", abi.encode(_config));
    }
}
