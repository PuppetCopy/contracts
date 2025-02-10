// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IGmxReferralStorage} from "../position/interface/IGmxReferralStorage.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {Error} from "../shared/Error.sol";
import {BankStore} from "../shared/store/BankStore.sol";
import {CoreContract} from "../utils/CoreContract.sol";
import {Precision} from "../utils/Precision.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {RewardStore} from "./store/RewardStore.sol";

contract RewardDistributor is CoreContract, ReentrancyGuardTransient {
    /// @notice Configuration parameters
    struct Config {
        uint distributionWindow; // Time window for reward distribution (in seconds)
    }

    /// @notice Reward tracking structure per user
    struct UserRewards {
        uint cumulativeRewardCheckpoint; // Last checkpoint of cumulative rewards per token
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
    ) CoreContract("RewardDistributor", "1", _authority) {
        rewardToken = _rewardToken;
        vToken = _vToken;
        store = _store;
        lastDistributionTime = block.timestamp;
    }

    /// @notice Calculate currently available rewards for distribution.
    function pendingDistribution() public view returns (uint distributable) {
        uint elapsed = block.timestamp - lastDistributionTime;
        if (config.distributionWindow == 0) {
            // Distribution period must be nonzero; if misconfigured return 0.
            return 0;
        }
        uint calculated = totalUndistributed * elapsed / config.distributionWindow;
        distributable = Math.min(calculated, totalUndistributed);
    }

    /// @notice Get claimable rewards for a user.
    function claimable(
        address user
    ) external view returns (uint) {
        UserRewards memory ur = userRewards[user];
        uint pending = pendingDistribution();
        uint totSupply = vToken.totalSupply();
        uint pendingPerToken = totSupply > 0 ? Precision.toFactor(pending, totSupply) : 0;
        uint currentCumulative = cumulativeRewardPerToken + pendingPerToken;
        uint userBalance = vToken.balanceOf(user);
        return
            ur.accrued + _calculatePendingRewardPerToken(ur.cumulativeRewardCheckpoint, currentCumulative, userBalance);
    }

    /// @notice Deposit new rewards into the system.
    /// @param depositor The address depositing rewards.
    /// @param amount Amount of reward tokens to deposit.
    function deposit(address depositor, uint amount) external auth nonReentrant {
        if (amount == 0) revert Error.RewardLogic__InvalidAmount();

        _distribute();
        totalUndistributed += amount;

        store.transferIn(rewardToken, depositor, amount);
        _logEvent("Deposit", abi.encode(depositor, amount));
    }

    /// @notice Claim accrued rewards.
    /// @param user The address whose rewards are claimed.
    /// @param receiver The address receiving the rewards.
    /// @param amount The amount of rewards to claim.
    function claim(address user, address receiver, uint amount) external auth nonReentrant {
        if (amount == 0) revert Error.RewardLogic__InvalidAmount();

        uint currentCumulative = _distribute();
        UserRewards storage ur = userRewards[user];
        uint userBalance = vToken.balanceOf(user);

        // Update the user's accrued rewards up to now.
        ur.accrued += _calculatePendingRewardPerToken(ur.cumulativeRewardCheckpoint, currentCumulative, userBalance);
        ur.cumulativeRewardCheckpoint = currentCumulative;

        if (amount > ur.accrued) {
            revert Error.RewardLogic__InsufficientRewards(ur.accrued);
        }
        ur.accrued -= amount;

        store.transferOut(rewardToken, receiver, amount);
        _logEvent("Claim", abi.encode(user, receiver, amount));
    }

    /// @notice Update reward accounting for a specific user.
    /// @param user The user whose rewards are to be updated.
    function updateUserRewards(
        address user
    ) external auth nonReentrant {
        uint currentCumulative = _distribute();
        UserRewards storage ur = userRewards[user];
        uint userBalance = vToken.balanceOf(user);

        ur.accrued += _calculatePendingRewardPerToken(ur.cumulativeRewardCheckpoint, currentCumulative, userBalance);
        ur.cumulativeRewardCheckpoint = currentCumulative;
    }

    /// @notice Distribute pending rewards to the system.
    function distribute() external auth nonReentrant returns (uint) {
        return _distribute();
    }

    // --- Internal Functions --- //

    /// @dev Internal distribution handler.
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

    /// @dev Calculate pending rewards between two checkpoints.
    function _calculatePendingRewardPerToken(
        uint userCheckpoint,
        uint currentCumulative,
        uint userBalance
    ) internal pure returns (uint) {
        return userBalance * (currentCumulative - userCheckpoint) / Precision.FLOAT_PRECISION;
    }

    // --- Governance Functions --- //

    /// @notice Update referral code ownership.
    function transferReferralOwnership(
        IGmxReferralStorage referralStorage,
        bytes32 code,
        address newOwner
    ) external auth {
        referralStorage.setCodeOwner(code, newOwner);
    }

    /// @notice Update contract configuration.
    /// @dev Expects ABI-encoded data that decodes to a `Config` struct.
    function _setConfig(
        bytes calldata data
    ) internal override {
        Config memory newConfig = abi.decode(data, (Config));
        require(newConfig.distributionWindow > 0, "RewardDistributor: distribution period must be > 0");
        config = newConfig;
    }
}
