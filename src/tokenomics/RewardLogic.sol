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
/// @notice contract features a token-based incentive buy-back, it has self-contained mechanism operates without relying
/// on external price oracles or a single liquidity pool for each token like ETH, USDC etc. also Manages the
/// distribution of rewards within the protocol, including locking mechanisms and bonus multipliers
/// for token holders.
//// @dev It calculates rewards for contributors based on a cumulative distribution rate, which increases with each
/// PUPPET token sale, enabling users to claim PUPPET rewards proportionate to their token contributions
/// @dev This contract handles the logic for reward emissions, locking tokens for voting power, and distributing rewards
/// to token holders.
/// It integrates with VotingEscrow for locking mechanisms, PuppetToken for minting rewards, RewardStore for tracking
/// reward accruals, and
/// RevenueStore for managing revenue balances
contract RewardLogic is CoreContract {
    /// @notice Struct to hold configuration parameters.
    struct Config {
        uint distributionTimeframe;
        uint baselineEmissionRate;
    }

    /// @notice The configuration parameters for the RewardLogic
    Config public config;

    /// @notice The contract used for minting rewards.
    IERC20Mintable public immutable rewardToken;

    /// @notice The RewardStore contract used for tracking reward accruals
    RewardStore public immutable store;

    /// @notice The token contract used for voting power
    IERC20 public immutable vToken;

    function getClaimableEmission(IERC20 token, address user) public view returns (uint) {
        uint tokenEmissionRewardPerTokenCursor = store.tokenEmissionRewardPerTokenCursor();
        RewardStore.UserRewardCursor memory userCursor = getUserCursor(user, tokenEmissionRewardPerTokenCursor);

        uint rewardPerTokenCursor = tokenEmissionRewardPerTokenCursor
            + Precision.toFactor(
                getPendingEmission(token), //
                vToken.totalSupply()
            );

        return userCursor.accruedReward
            + getUserPendingReward(
                rewardPerTokenCursor, //
                userCursor.rewardPerToken,
                vToken.balanceOf(user)
            );
    }

    function getUserAccruedReward(
        IERC20 token,
        address user,
        uint cumulativeRewardPerContribution
    ) public view returns (uint) {
        uint userRewardPerContrib = store.getUserRewardPerContributionCursor(token, user);
        uint accuredReward = store.getUserAccruedReward(token, user);

        if (cumulativeRewardPerContribution > userRewardPerContrib) {
            uint userCumContribution = store.getUserCumulativeContribution(token, user);

            return accuredReward
                + userCumContribution * (cumulativeRewardPerContribution - userRewardPerContrib) / Precision.FLOAT_PRECISION;
        }

        return accuredReward;
    }

    function getClaimable(IERC20 token, address contributor) external view returns (uint) {
        return getUserAccruedReward(token, contributor, store.getCumulativeRewardPerContribution(token));
    }

    /// @notice Retrieves the revenue balance of a specific token in the revenue store.
    /// @param token The address of the token whose balance is to be retrieved.
    /// @return The balance of the specified token in the revenue store.
    function getRevenueBalance(IERC20 token) external view returns (uint) {
        return store.getTokenBalance(token);
    }

    constructor(
        IAuthority _authority,
        EventEmitter _eventEmitter,
        IERC20Mintable _rewardToken,
        RewardStore _store,
        Config memory _config
    ) CoreContract("RewardLogic", "1", _authority, _eventEmitter) {
        store = _store;
        // revenueStore = _revenueStore;
        rewardToken = _rewardToken;

        _setConfig(_config);
    }

    function contribute(
        IERC20 _token, //
        address _depositor,
        address _user,
        uint _value
    ) external auth {
        store.contribute(_token, _depositor, _user, _value);
    }

    function contributeMany(
        IERC20 _token, //
        address _depositor,
        address[] calldata _userList,
        uint[] calldata _valueList
    ) external auth {
        store.contributeMany(_token, _depositor, _userList, _valueList);
    }

    /// @notice Executes the buyback of revenue tokens using the protocol's accumulated fees.
    /// @param depositor The address that deposits the buyback token.
    /// @param receiver The address that will receive the revenue token.
    /// @param token The address of the revenue token to be bought back.
    /// @param amount The amount of revenue tokens to be bought back.
    function buyback(address depositor, address receiver, IERC20 token, uint amount) external auth {
        uint thresholdAmount = store.getBuybackQuote(token);

        if (thresholdAmount == 0) revert RewardLogic__InvalidClaimToken();

        store.transferIn(rewardToken, depositor, thresholdAmount);
        store.transferOut(token, receiver, amount);

        uint nextCumulativeTokenPerContrib = store.increaseCumulativeRewardPerContribution(
            token, //
            Precision.toFactor(thresholdAmount, amount)
        );

        logEvent(
            "buyback()", abi.encode(token, depositor, receiver, nextCumulativeTokenPerContrib, thresholdAmount, amount)
        );
    }

    /// @notice Claims the rewards for a specific token contribution.
    /// @param token The address of the token for which the rewards are to be claimed.
    /// @param contributor The address of the contributor for whom the rewards are to be claimed.
    /// @param receiver The address that will receive the claimed rewards.
    /// @param amount The amount of rewards to be claimed.
    /// @return The amount of rewards claimed.
    function claimContribution(
        IERC20 token,
        address contributor,
        address receiver,
        uint amount
    ) external returns (uint) {
        uint cumTokenPerContrib = store.getCumulativeRewardPerContribution(token);
        uint accruedReward = getUserAccruedReward(token, contributor, cumTokenPerContrib);

        if (amount > accruedReward) revert RewardLogic__InsufficientClaimableReward();

        accruedReward -= amount;

        store.setUserRewardPerContributionCursor(token, contributor, cumTokenPerContrib);
        store.setUserAccruedReward(token, contributor, accruedReward);

        uint reward = Precision.applyFactor(config.baselineEmissionRate, amount);

        rewardToken.mint(receiver, amount);

        logEvent("claimContribution()", abi.encode(token, contributor, amount, accruedReward, reward));

        return reward;
    }

    /// @notice Claims emission rewards for the caller and sends them to the specified receiver.
    /// @dev Calculates the claimable rewards for the caller based on the current reward cursor and the user's balance
    /// in the VotingEscrow contract.
    /// If the reward is non-zero, it updates the user's emission cursor, sets their accrued reward to zero, and
    /// transfers the reward to the receiver.
    /// @param receiver The address where the claimed rewards should be sent.
    function claimEmission(address user, address receiver, uint amount) public auth {
        uint nextRewardPerTokenCursor = distribute();

        RewardStore.UserRewardCursor memory cursor = getUserCursor(user, nextRewardPerTokenCursor);

        if (amount > cursor.accruedReward) revert RewardLogic__NoClaimableAmount();

        cursor.accruedReward -= amount;

        store.setUserRewardCursor(user, cursor);
        store.transferOut(rewardToken, receiver, amount);

        logEvent("claimEmission()", abi.encode(user, receiver, amount));
    }

    function userDistribute(address user) external auth returns (RewardStore.UserRewardCursor memory cursor) {
        uint nextRewardPerTokenCursor = distribute();
        cursor = getUserCursor(user, nextRewardPerTokenCursor);
        store.setUserRewardCursor(user, cursor);
    }

    // internal

    function distribute() internal returns (uint) {
        uint timeElapsed = block.timestamp - store.tokenEmissionTimestamp();
        uint tokenBalance = store.getTokenBalance(rewardToken);
        uint rate = store.tokenEmissionRate();
        uint nextRate = tokenBalance / config.distributionTimeframe;

        if (timeElapsed > config.distributionTimeframe) {
            store.setTokenEmissionRate(0);
        } else if (nextRate > rate) {
            rate = nextRate;
            store.setTokenEmissionRate(nextRate);
        }

        store.setTokenEmissionTimestamp(block.timestamp);

        uint emission = Math.min(timeElapsed * rate, tokenBalance);

        if (emission == 0 || tokenBalance == 0) {
            return store.tokenEmissionRewardPerTokenCursor();
        }

        uint supply = vToken.totalSupply();
        uint rewardPerToken = store.incrementCumulativePerContribution(Precision.toFactor(emission, supply));

        logEvent("distribute()", abi.encode(rewardPerToken, emission));

        return rewardPerToken;
    }

    function getUserCursor(
        address user,
        uint rewardPerTokenCursor
    ) internal view returns (RewardStore.UserRewardCursor memory cursor) {
        cursor = store.getUserRewardCursor(user);
        cursor.rewardPerToken = rewardPerTokenCursor;
        cursor.accruedReward = cursor.accruedReward
            + getUserPendingReward(rewardPerTokenCursor, cursor.rewardPerToken, vToken.balanceOf(user));
    }

    function getPendingEmission(IERC20 revenueToken) internal view returns (uint) {
        uint emissionBalance = store.getTokenBalance(revenueToken);
        uint lastTimestamp = store.tokenEmissionTimestamp();
        uint rate = store.tokenEmissionRate();

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

    /// @notice Set the mint rate limit for the token.
    /// @param _config The new rate limit configuration.
    function setConfig(Config calldata _config) external auth {
        _setConfig(_config);
    }

    // https://github.com/gmx-io/gmx-synthetics/blob/main/contracts/mock/ReferralStorage.sol#L127
    function transferReferralOwnership(
        IGmxReferralStorage _referralStorage,
        bytes32 _code,
        address _newOwner
    ) external auth {
        _referralStorage.setCodeOwner(_code, _newOwner);
    }

    /// @dev Internal function to set the configuration.
    /// @param _config The configuration to set.
    function _setConfig(Config memory _config) internal {
        config = _config;
        logEvent("setConfig()", abi.encode(_config));
    }

    /// @notice Error emitted when the claimable amount is insufficient
    error RewardLogic__InssufficientClaimableAmount();
    /// @notice Error emitted when there is no claimable amount for a user
    error RewardLogic__NoClaimableAmount();
    /// @notice Error emitted when the claim token is invalid
    error RewardLogic__InvalidClaimToken();
    /// @notice Error emitted when the claimable reward is insufficient
    error RewardLogic__InsufficientClaimableReward();
}
