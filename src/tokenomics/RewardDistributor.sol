// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IGmxReferralStorage} from "../position/interface/IGmxReferralStorage.sol";
import {Error} from "../shared/Error.sol";
import {BankStore} from "../shared/store/BankStore.sol";
import {CoreContract} from "../utils/CoreContract.sol";
import {Precision} from "../utils/Precision.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {RewardStore} from "./store/RewardStore.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract RewardDistributor is CoreContract {
    /// @notice Configuration parameters
    struct Config {
        uint distributionPeriod; // Time window for reward distribution (in seconds)
    }

    /// @notice Reward tracking structure per user
    struct UserRewards {
        uint lastRewardPerToken; // Last checkpoint of cumulative rewards per token
        uint accrued; // Accrued rewards waiting to be claimed
    }

    // Immutable contract references
    IERC20 public immutable rewardToken;
    IERC20 public immutable vToken;
    RewardStore public immutable store;

    // Reward distribution state
    Config public config;
    uint public cumulativeRewardPerToken;
    uint public totalUndistributed; // Total rewards deposited but not yet distributed
    uint public lastDistributionTime;
    mapping(address => UserRewards) public userRewards;

    constructor(
        IAuthority _authority,
        IERC20 _rewardToken,
        IERC20 _vToken,
        RewardStore _store
    ) CoreContract("RewardLogic", "1", _authority) {
        rewardToken = _rewardToken;
        vToken = _vToken;
        store = _store;
    }

    /// @notice Calculate currently available rewards for distribution
    function pendingDistribution() public view returns (uint distributable) {
        uint elapsed = block.timestamp - lastDistributionTime;
        distributable = Math.min(totalUndistributed * elapsed / config.distributionPeriod, totalUndistributed);
    }

    /// @notice Get claimable rewards for a user
    function claimable(
        address user
    ) external view returns (uint) {
        UserRewards memory ur = userRewards[user];
        uint pendingPerToken = Precision.toFactor(pendingDistribution(), vToken.totalSupply());
        uint currentCumulative = cumulativeRewardPerToken + pendingPerToken;

        return ur.accrued + _calculatePending(ur.lastRewardPerToken, currentCumulative, vToken.balanceOf(user));
    }

    /// @notice Deposit new rewards into the system
    function deposit(address depositor, uint amount) external auth {
        if (amount == 0) revert Error.RewardLogic__InvalidAmount();

        _distribute();
        totalUndistributed += amount;

        store.transferIn(rewardToken, depositor, amount);
        _logEvent("Deposit", abi.encode(depositor, amount));
    }

    /// @notice Claim accrued rewards
    function claim(address user, address receiver, uint amount) external auth {
        if (amount == 0) revert Error.RewardLogic__InvalidAmount();

        uint currentCumulative = _distribute();
        UserRewards storage ur = userRewards[user];

        ur.accrued += _calculatePending(ur.lastRewardPerToken, currentCumulative, vToken.balanceOf(user));
        ur.lastRewardPerToken = currentCumulative;

        if (amount > ur.accrued) revert Error.RewardLogic__InsufficientRewards(ur.accrued);
        ur.accrued -= amount;

        store.transferOut(rewardToken, receiver, amount);
        _logEvent("Claim", abi.encode(user, receiver, amount));
    }

    /// @notice Update reward accounting for a specific user
    function updateUserRewards(
        address user
    ) external auth {
        uint currentCumulative = _distribute();
        UserRewards storage ur = userRewards[user];

        ur.accrued += _calculatePending(ur.lastRewardPerToken, currentCumulative, vToken.balanceOf(user));
        ur.lastRewardPerToken = currentCumulative;
    }

    /// @notice Distribute pending rewards to the system
    function distribute() external auth returns (uint) {
        return _distribute();
    }

    // --- Internal Functions --- //

    /// @dev Internal distribution handler
    function _distribute() internal returns (uint) {
        uint emission = pendingDistribution();
        uint totalVTokens = vToken.totalSupply();
        lastDistributionTime = block.timestamp;

        if (emission > 0 && totalVTokens > 0) {
            totalUndistributed -= emission;
            uint rewardIncrement = Precision.toFactor(emission, totalVTokens);
            cumulativeRewardPerToken += rewardIncrement;

            _logEvent("Distribute", abi.encode(emission, totalVTokens));
        }
        return cumulativeRewardPerToken;
    }

    /// @dev Calculate pending rewards between two checkpoints
    function _calculatePending(
        uint userCheckpoint,
        uint currentCumulative,
        uint userBalance
    ) internal pure returns (uint) {
        return userBalance * (currentCumulative - userCheckpoint) / Precision.FLOAT_PRECISION;
    }

    // --- Governance Functions --- //

    /// @notice Update referral code ownership
    function transferReferralOwnership(
        IGmxReferralStorage referralStorage,
        bytes32 code,
        address newOwner
    ) external auth {
        referralStorage.setCodeOwner(code, newOwner);
    }

    /// @notice Update contract configuration
    function _setConfig(
        bytes calldata data
    ) internal override {
        config = abi.decode(data, (Config));
    }
}
