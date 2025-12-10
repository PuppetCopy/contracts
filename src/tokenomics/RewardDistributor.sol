// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.31;

import {IGmxReferralStorage} from "../position/interface/IGmxReferralStorage.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {CoreContract} from "../utils/CoreContract.sol";
import {Error} from "../utils/Error.sol";
import {Precision} from "../utils/Precision.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {RewardStore} from "./RewardStore.sol";

contract RewardDistributor is CoreContract {
    /// @notice Configuration parameters
    struct Config {
        uint transferOutGasLimit;
        uint distributionWindow;
    }

    struct UserRewards {
        uint cumulativeRewardCheckpoint;
        uint accrued;
    }

    IERC20 public immutable rewardToken;
    IERC20 public immutable vToken;
    RewardStore public immutable store;

    mapping(address => UserRewards) public userRewardMap;

    uint public cumulativeRewardPerToken;
    uint public totalUndistributed; // Total rewards deposited but not yet distributed
    uint public lastDistributionTime;

    Config config;

    constructor(
        IAuthority _authority,
        IERC20 _rewardToken,
        IERC20 _vToken,
        RewardStore _store
    ) CoreContract(_authority, bytes("")) {
        rewardToken = _rewardToken;
        vToken = _vToken;
        store = _store;
        lastDistributionTime = block.timestamp;
    }

    /// @notice Calculate currently available rewards for distribution.
    function pendingDistribution() public view returns (uint) {
        uint _elapsed = block.timestamp - lastDistributionTime;
        uint _calculated = totalUndistributed * _elapsed / config.distributionWindow;

        return Math.min(_calculated, totalUndistributed);
    }

    /// @notice Get claimable rewards for a user.
    function claimable(
        address _user
    ) external view returns (uint) {
        UserRewards memory ur = userRewardMap[_user];
        uint _pending = pendingDistribution();
        uint _totSupply = vToken.totalSupply();
        uint _pendingPerToken = _totSupply > 0 ? Precision.toFactor(_pending, _totSupply) : 0;
        uint _nextCumulativeCheckpoint = cumulativeRewardPerToken + _pendingPerToken;
        uint _userBalance = vToken.balanceOf(_user);

        return ur.accrued
            + _calculatePendingRewardPerToken(ur.cumulativeRewardCheckpoint, _nextCumulativeCheckpoint, _userBalance);
    }

    /// @notice Deposit new rewards into the system.
    /// @param _depositor The address depositing rewards.
    /// @param _amount Amount of reward tokens to deposit.
    function deposit(address _depositor, uint _amount) external auth {
        if (_amount == 0) revert Error.RewardDistributor__InvalidAmount();

        _distribute();
        totalUndistributed += _amount;
        store.transferIn(rewardToken, _depositor, _amount);

        _logEvent("Deposit", abi.encode(_depositor, _amount));
    }

    /// @notice Claim accrued rewards.
    /// @param _user The address whose rewards are claimed.
    /// @param _receiver The address receiving the rewards.
    /// @param _amount The amount of rewards to claim.
    function claim(address _user, address _receiver, uint _amount) external auth {
        if (_amount == 0) revert Error.RewardDistributor__InvalidAmount();

        uint _currentCumulative = _distribute();
        UserRewards memory _userReward = userRewardMap[_user];
        uint _userBalance = vToken.balanceOf(_user);
        uint _nextAccrued = _userReward.accrued
            + _calculatePendingRewardPerToken(_userReward.cumulativeRewardCheckpoint, _currentCumulative, _userBalance);

        if (_amount > _nextAccrued) revert Error.RewardDistributor__InsufficientRewards(_userReward.accrued);

        // Update the user's accrued rewards up to now.
        _userReward.cumulativeRewardCheckpoint = _currentCumulative;
        _userReward.accrued -= _amount;

        userRewardMap[_user] = _userReward;
        store.transferOut(config.transferOutGasLimit, rewardToken, _receiver, _amount);

        _logEvent("Claim", abi.encode(_user, _receiver, _amount));
    }

    /// @dev Internal distribution handler.
    function _distribute() internal returns (uint) {
        uint _emission = pendingDistribution();
        uint _totalVTokens = vToken.totalSupply();

        lastDistributionTime = block.timestamp;

        if (_emission > 0 && _totalVTokens > 0) {
            totalUndistributed -= _emission;
            uint _cumulativeRewardPerToken = cumulativeRewardPerToken + Precision.toFactor(_emission, _totalVTokens);
            cumulativeRewardPerToken += _cumulativeRewardPerToken;
            _logEvent("Distribute", abi.encode(_cumulativeRewardPerToken, _emission));

            return _cumulativeRewardPerToken;
        }

        return cumulativeRewardPerToken;
    }

    /// @dev Calculate pending rewards between two checkpoints.
    function _calculatePendingRewardPerToken(
        uint _userCheckpoint,
        uint _currentCumulative,
        uint _userBalance
    ) internal pure returns (uint) {
        return _userBalance * (_currentCumulative - _userCheckpoint) / Precision.FLOAT_PRECISION;
    }

    // --- Governance Functions --- //

    /// @notice Update referral code ownership.
    function transferReferralOwnership(
        IGmxReferralStorage _referralStorage,
        bytes32 _code,
        address _newOwner
    ) external auth {
        _referralStorage.setCodeOwner(_code, _newOwner);
    }

    /// @notice Update contract configuration.
    /// @dev Expects ABI-encoded data that decodes to a `Config` struct.
    function _setConfig(
        bytes memory _data
    ) internal override {
        Config memory newConfig = abi.decode(_data, (Config));
        if (newConfig.distributionWindow == 0) revert("RewardDistributor: distribution period must be > 0");
        config = newConfig;
    }
}
