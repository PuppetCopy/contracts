// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {IGmxReferralStorage} from "../position/interface/IGmxReferralStorage.sol";
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

    /// @notice The configuration parameters for the RewardLogic
    Config public config;

    /// @notice The contract used for minting rewards.
    IERC20 public immutable rewardToken;

    /// @notice The RewardStore contract used for tracking reward accruals
    RewardStore public immutable store;

    /// @notice The token contract used for voting power
    IERC20 public immutable vToken;

    function getClaimable(address user) external view returns (uint) {
        uint pendingReward = getEmissionReward();

        uint cumulativeRewardPerContribution =
            store.cumulativeRewardPerToken() + Precision.toFactor(pendingReward, vToken.totalSupply());
        RewardStore.UserRewardCursor memory cursor = store.getUserRewardCursor(user);

        return cursor.accruedReward
            + vToken.balanceOf(user) * (cumulativeRewardPerContribution - cursor.rewardPerToken) / Precision.FLOAT_PRECISION;
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
        RewardStore.UserRewardCursor memory cursor = userDistribute(user);

        if (amount > cursor.accruedReward) revert RewardLogic__NoClaimableAmount(cursor.accruedReward);

        cursor.accruedReward -= amount;

        store.setUserRewardCursor(user, cursor);
        store.transferOut(rewardToken, receiver, amount);

        logEvent("claim()", abi.encode(user, receiver, amount));
    }

    function userDistribute(address user) public auth returns (RewardStore.UserRewardCursor memory cursor) {
        uint nextRewardPerTokenCursor = distribute();
        cursor = store.getUserRewardCursor(user);

        cursor.accruedReward +=
            vToken.balanceOf(user) * (nextRewardPerTokenCursor - cursor.rewardPerToken) / Precision.FLOAT_PRECISION;

        store.setUserRewardCursor(user, cursor);
    }

    // internal

    /// @notice Distributes the rewards to the users based on the current token emission rate and the time elapsed
    /// @return The updated cumulative reward per contribution state
    function distribute() internal returns (uint) {
        uint amount = getEmissionReward();
        uint supply = vToken.totalSupply();

        store.setLastRewardTimestamp(block.timestamp);

        if (amount == 0 || supply == 0) return store.cumulativeRewardPerToken();

        store.interIn(config.distributionStore, rewardToken, amount);

        uint rewardPerToken = store.incrementCumulativePerContribution(Precision.toFactor(amount, supply));

        logEvent("distribute()", abi.encode(rewardPerToken, supply, amount));

        return rewardPerToken;
    }

    function getEmissionReward() internal view returns (uint reward) {
        uint timeElapsed = block.timestamp - store.lastRewardTimestamp();
        uint balance = config.distributionStore.getTokenBalance(rewardToken);

        reward = Math.min(balance * timeElapsed / config.distributionTimeframe, balance);
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
    error RewardLogic__NoClaimableAmount(uint accruedReward);
}
