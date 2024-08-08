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

import {Router} from "../shared/Router.sol";
import {RewardStore} from "./store/RewardStore.sol";
import {VotingEscrow, MAXTIME} from "./VotingEscrow.sol";
import {PuppetToken} from "./PuppetToken.sol";

contract RewardLogic is Permission, EIP712, ReentrancyGuardTransient {
    event RewardLogic__SetConfig(uint timestmap, Config callConfig);
    event RewardLogic__Lock(IERC20 token, uint baselineEmissionRate, address user, uint accuredReward, uint duration, uint rewardInToken);
    event RewardLogic__Exit(IERC20 token, uint baselineEmissionRate, address user, uint rewardInToken);
    event RewardLogic__Claim(address user, address receiver, uint rewardPerTokenCursor, uint amount);

    event RewardLogic__Distribute(IERC20 token, uint distributionTimeframe, uint supply, uint nextRewardPerTokenCursor);
    event RewardLogic__Buyback(address buyer, uint thresholdAmount, IERC20 token, uint rewardPerContributionCursor, uint totalFee);

    struct Config {
        uint baselineEmissionRate;
        uint optionLockTokensBonusMultiplier;
        uint lockLiquidTokensBonusMultiplier;
        uint distributionTimeframe;
    }

    Config config;

    VotingEscrow immutable votingEscrow;
    RewardStore immutable store;
    PuppetToken immutable puppetToken;

    function getClaimableEmission(IERC20 token, address user) public view returns (uint) {
        uint pendingEmission = getPendingEmission(token);
        uint rewardPerTokenCursor =
            store.getTokenEmissionRewardPerTokenCursor(token) + Precision.toFactor(pendingEmission, votingEscrow.totalSupply());

        RewardStore.UserEmissionCursor memory userCursor = store.getUserEmissionReward(token, user);

        return userCursor.accruedReward + getUserPendingReward(rewardPerTokenCursor, userCursor.rewardPerToken, votingEscrow.balanceOf(user));
    }

    function getDurationBonusMultiplier(uint durationBonusMultiplier, uint duration) internal pure returns (uint) {
        uint durationMultiplier = Precision.applyFactor(durationBonusMultiplier, MAXTIME);

        return Precision.toFactor(duration, durationMultiplier);
    }

    function getBonusReward(uint durationBonusMultiplier, uint reward, uint duration) internal pure returns (uint) {
        uint baselineAmount = Precision.applyFactor(config.baselineEmissionRate, reward);
        uint durationMultiplier = getDurationBonusMultiplier(durationBonusMultiplier, duration);
        return Precision.applyFactor(durationMultiplier, baselineAmount);
    }

    constructor(
        IAuthority _authority,
        Router _router,
        VotingEscrow _votingEscrow,
        PuppetToken _puppetToken,
        RewardStore _store,
        Config memory _callConfig
    ) Permission(_authority) EIP712("Reward Router", "1") {
        votingEscrow = _votingEscrow;
        store = _store;
        puppetToken = _puppetToken;

        _setConfig(_callConfig);
    }

    // external

    function buybackContributionToken(address source, address depositor, IERC20 token, uint amount) external nonReentrant {
        uint thresholdAmount = store.getBuybackTokenThresholdAmount(token);

        if (thresholdAmount == 0) revert RewardLogic__InvalidClaimToken();

        store.transferIn(puppetToken, depositor, thresholdAmount);
        store.transferOut(token, source, amount);
        uint rewardPerContributionCursor = store.increaseTokenPerContributionCursor(token, Precision.toFactor(thresholdAmount, amount));

        emit RewardLogic__Buyback(depositor, thresholdAmount, token, rewardPerContributionCursor, amount);
    }

    function lockContribution(IERC20 token, uint duration) public nonReentrant returns (uint) {
        uint contributionBalance = store.getUserContributionBalance(token, msg.sender);

        if (contributionBalance > 0) revert RewardLogic__AmountExceedsContribution();

        uint tokenPerContributionCursor = store.getTokenPerContributionCursor(token);
        uint rewardInToken = getBonusReward(
            getUserPendingReward(tokenPerContributionCursor, store.getUserTokenPerContributionCursor(token, msg.sender), contributionBalance),
            config.optionLockTokensBonusMultiplier,
            duration
        );

        RewardStore.UserEmissionCursor memory userEmissionCursor = store.getUserEmissionReward(token, msg.sender);

        userEmissionCursor.rewardPerToken = distribute(token);
        userEmissionCursor.accruedReward = getUserPendingReward(
            tokenPerContributionCursor, //
            userEmissionCursor.rewardPerToken,
            votingEscrow.balanceOf(msg.sender)
        );

        store.setUserContributionBalance(token, msg.sender, 0);
        store.setUserTokenPerContributionCursor(token, msg.sender, tokenPerContributionCursor);
        store.setUserEmissionReward(token, msg.sender, userEmissionCursor);

        puppetToken.mint(address(this), rewardInToken);
        votingEscrow.lock(address(this), msg.sender, rewardInToken, duration);

        emit RewardLogic__Lock(token, config.baselineEmissionRate, msg.sender, rewardInToken, duration, rewardInToken);
    }

    function exitContribution(IERC20 token) external nonReentrant {
        uint contributionBalance = store.getUserContributionBalance(token, msg.sender);

        if (contributionBalance > 0) revert RewardLogic__AmountExceedsContribution();

        uint tokenPerContributionCursor = store.getTokenPerContributionCursor(token);
        uint rewardInToken = Precision.applyFactor(
            config.baselineEmissionRate,
            getUserPendingReward(tokenPerContributionCursor, store.getUserTokenPerContributionCursor(token, msg.sender), contributionBalance)
        );

        store.setUserContributionBalance(token, msg.sender, 0);
        store.setUserTokenPerContributionCursor(token, msg.sender, tokenPerContributionCursor);
        puppetToken.mint(address(this), rewardInToken);

        emit RewardLogic__Exit(token, config.baselineEmissionRate, msg.sender, rewardInToken);
    }

    function lockTokens(address user, uint unlockDuration, uint amount) external nonReentrant returns (uint) {
        uint rewardAfterMultiplier = getBonusReward(config.lockLiquidTokensBonusMultiplier, amount, unlockDuration);

        puppetToken.mint(address(this), amount);
        votingEscrow.lock(user, user, amount, unlockDuration);

        return rewardAfterMultiplier;
    }

    function vestTokens(uint amount) public nonReentrant {
        votingEscrow.vest(msg.sender, msg.sender, amount);
    }

    function veClaim(address user, address receiver, uint amount) public nonReentrant {
        votingEscrow.claim(user, receiver, amount);
    }

    function claimEmission(IERC20 token, address receiver) public nonReentrant returns (uint) {
        uint nextRewardPerTokenCursor = distribute(token);

        RewardStore.UserEmissionCursor memory userCursor = store.getUserEmissionReward(token, msg.sender);

        uint reward =
            userCursor.accruedReward + getUserPendingReward(nextRewardPerTokenCursor, userCursor.rewardPerToken, votingEscrow.balanceOf(msg.sender));

        if (reward == 0) revert RewardLogic__NoClaimableAmount();

        userCursor.accruedReward = 0;
        userCursor.rewardPerToken = nextRewardPerTokenCursor;

        store.setUserEmissionReward(token, msg.sender, userCursor);
        store.transferOut(token, receiver, reward);

        emit RewardLogic__Claim(msg.sender, receiver, nextRewardPerTokenCursor, reward);

        return reward;
    }

    function distribute(IERC20 token) public nonReentrant returns (uint) {
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

    function getPendingEmission(IERC20 token) internal view returns (uint) {
        uint emissionBalance = store.getTokenBalance(token);
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

    error RewardLogic__NoClaimableAmount();
    error RewardLogic__UnacceptableTokenPrice(uint tokenPrice);
    error RewardLogic__InvalidClaimPrice();
    error RewardLogic__InvalidDuration();
    error RewardLogic__InvalidClaimToken();
    error RewardLogic__NotingToClaim();
    error RewardLogic__AmountExceedsContribution();
    error RewardLogic__InvalidWeightFactors();
}
