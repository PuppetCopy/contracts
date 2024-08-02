// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {Precision} from "./../../utils/Precision.sol";
import {PuppetToken} from "../PuppetToken.sol";
import {RewardStore} from "./../store/RewardStore.sol";
import {VotingEscrow, MAXTIME} from "../VotingEscrow.sol";

library RewardLogic {
    enum Choice {
        LOCK,
        EXIT
    }

    event RewardLogic__Lock(address user, IERC20 revenueToken, uint accuredReward, uint rewardInToken, uint lockDuration);
    event RewardLogic__Exit(address user, IERC20 revenueToken, uint accuredReward, uint rewardInToken);

    event RewardLogic__Distribute(IERC20 revenueToken, uint distributionTimeframe, uint supply, uint nextRewardPerTokenCursor);

    event RewardLogic__Claimed(address user, address receiver, uint rewardPerTokenCursor, uint amount);
    event RewardLogic__Buyback(address buyer, uint thresholdAmount, IERC20 token, uint rewardPerContributionCursor, uint totalFee);

    struct CallOptionParmas {
        IERC20 revenueToken;
        address user;
        uint rate;
        uint distributionTimeframe;
        uint cugarAmount;
    }

    function getLockRewardMultiplier(uint _bonusMultiplier, uint _lockDuration) public pure returns (uint) {
        return Precision.applyFactor(_bonusMultiplier, Precision.toFactor(_lockDuration, MAXTIME));
    }

    function getClaimable(
        VotingEscrow votingEscrow, //
        RewardStore store,
        IERC20 token,
        uint distributionTimeframe,
        address user
    ) internal view returns (uint) {
        uint pendingEmission = getPendingEmission(store, token, distributionTimeframe);
        uint rewardPerTokenCursor = store.getRewardPerTokenCursor(token) + Precision.toFactor(pendingEmission, votingEscrow.totalSupply());

        return getUserAccuredRewards(store, token, user, rewardPerTokenCursor, votingEscrow.balanceOf(user));
    }

    function getUserAccuredRewards(
        RewardStore store, //
        IERC20 token,
        address user,
        uint rewardPerTokenCursor,
        uint userBalance
    ) internal view returns (uint) {
        RewardStore.UserTokenCursor memory userCursor = store.getUserTokenCursor(token, user);
        uint rewardDelta = rewardPerTokenCursor - userCursor.rewardPerToken;
        uint pendingReward = userBalance * rewardDelta / Precision.FLOAT_PRECISION;

        return userCursor.accruedReward + pendingReward;
    }

    function getPendingEmission(
        RewardStore store, //
        IERC20 token,
        uint distributionTimeframe
    ) internal view returns (uint) {
        uint lastTimestamp = store.getTokenEmissionTimestamp(token);
        uint emissionBalance = store.getTokenBalance(token);
        uint rate = store.getTokenEmissionRate(token);

        uint nextRate = emissionBalance / distributionTimeframe;
        uint timeElapsed = block.timestamp - lastTimestamp;

        if (nextRate > rate) {
            rate = nextRate;
        }

        return Math.min(timeElapsed * nextRate, emissionBalance);
    }

    function buybackToken(
        RewardStore store, //
        address source,
        address depositor,
        PuppetToken puppetToken,
        IERC20 token,
        uint amount
    ) internal {
        uint thresholdAmount = store.getBuybackTokenThresholdAmount(token);

        if (thresholdAmount == 0) revert RewardLogic__InvalidClaimToken();

        store.transferIn(puppetToken, depositor, thresholdAmount);
        store.transferOut(token, source, amount);
        uint rewardPerContributionCursor = store.increaseTokenPerContributionCursor(token, Precision.toFactor(thresholdAmount, amount));

        emit RewardLogic__Buyback(depositor, thresholdAmount, token, rewardPerContributionCursor, amount);
    }

    function distribute(
        VotingEscrow votingEscrow, //
        RewardStore store,
        IERC20 token,
        uint distributionTimeframe
    ) internal returns (uint) {
        uint timeElapsed = block.timestamp - store.getTokenEmissionTimestamp(token);
        uint tokenBalance = store.getTokenBalance(token);
        uint rate = store.getTokenEmissionRate(token);
        uint nextRate = tokenBalance / distributionTimeframe;

        if (timeElapsed > distributionTimeframe) {
            store.setTokenEmissionRate(token, 0);
        } else if (nextRate > rate) {
            rate = nextRate;
            store.setTokenEmissionRate(token, nextRate);
        }

        store.setTokenEmissionTimestamp(token, block.timestamp);

        uint emission = Math.min(timeElapsed * rate, tokenBalance);

        if (emission == 0 || tokenBalance == 0) {
            return store.getRewardPerTokenCursor(token);
        }

        uint supply = votingEscrow.totalSupply();
        uint rewardPerToken = store.increaseRewardPerTokenCursor(token, Precision.toFactor(emission, supply));

        emit RewardLogic__Distribute(token, distributionTimeframe, supply, rewardPerToken);

        return rewardPerToken;
    }

    function distributeUser(
        VotingEscrow votingEscrow, //
        RewardStore store,
        IERC20 token,
        uint distributionTimeframe,
        address user
    ) internal returns (uint) {
        uint nextRewardPerTokenCursor = distribute(votingEscrow, store, token, distributionTimeframe);
        uint accruedReward = getUserAccuredRewards(store, token, user, nextRewardPerTokenCursor, votingEscrow.balanceOf(user));

        store.setUserTokenCursor(token, user, RewardStore.UserTokenCursor({rewardPerToken: nextRewardPerTokenCursor, accruedReward: accruedReward}));

        return accruedReward;
    }

    function veWithdraw(VotingEscrow votingEscrow, address user, address receiver, uint amount) internal {
        votingEscrow.claim(user, receiver, amount);
    }

    function lock(
        VotingEscrow votingEscrow, //
        RewardStore store,
        PuppetToken puppetToken,
        CallOptionParmas memory callParams,
        uint unlockDuration
    ) internal returns (uint) {
        if (unlockDuration > MAXTIME) revert RewardLogic__InvalidDuration();
        if (callParams.cugarAmount == 0) revert RewardLogic__NotingToClaim();

        store.decreaseUserSeedContribution(callParams.revenueToken, callParams.user, callParams.cugarAmount);

        uint accruedReward = distributeUser(
            votingEscrow,
            store, //
            callParams.revenueToken,
            callParams.distributionTimeframe,
            callParams.user
        );

        uint userTokenPerContribution = store.getTokenPerContributionCursor(callParams.revenueToken)
            - store.getUserTokenPerContributionCursor(callParams.revenueToken, callParams.user);
        store.setUserTokenPerContributionCursor(callParams.revenueToken, callParams.user, userTokenPerContribution);

        uint maxRewardInToken = callParams.cugarAmount * userTokenPerContribution / Precision.FLOAT_PRECISION;
        uint rewardInToken = Precision.applyFactor(maxRewardInToken, callParams.rate);

        puppetToken.mint(address(this), rewardInToken);
        votingEscrow.lock(address(this), callParams.user, rewardInToken, unlockDuration);

        emit RewardLogic__Lock(callParams.user, callParams.revenueToken, accruedReward, rewardInToken, unlockDuration);

        return callParams.cugarAmount;
    }

    function exit(
        VotingEscrow votingEscrow, //
        RewardStore store,
        PuppetToken puppetToken,
        CallOptionParmas memory callParams,
        address receiver
    ) internal returns (uint) {
        // store.decreaseUserSeedContribution(callParams.revenueToken, callParams.user, callParams.cugarAmount);

        // uint accuredReward = distributeUser(
        //     votingEscrow, //
        //     store,
        //     callParams.revenueToken,
        //     callParams.revenueSource,
        //     callParams.distributionTimeframe,
        //     callParams.user
        // );
        // uint maxPriceInRevenueToken = syncPrice(oracle, callParams.revenueToken, callParams.acceptableTokenPrice);
        // uint claimableInToken = Precision.applyBasisPoints(callParams.rate, callParams.cugarAmount * 1e18 / maxPriceInRevenueToken);

        // puppetToken.mint(receiver, claimableInToken);

        // emit RewardLogic__Exit(callParams.user, callParams.revenueToken, maxPriceInRevenueToken, claimableInToken, accuredReward);

        return 0;
    }

    function claim(
        VotingEscrow votingEscrow, //
        RewardStore store,
        IERC20 token,
        uint distributionTimeframe,
        address user,
        address receiver
    ) internal returns (uint) {
        uint nextRewardPerTokenCursor = distribute(votingEscrow, store, token, distributionTimeframe);
        uint accruedReward = getUserAccuredRewards(store, token, user, nextRewardPerTokenCursor, votingEscrow.balanceOf(user));

        if (accruedReward == 0) revert RewardLogic__NoClaimableAmount();

        store.setUserTokenCursor(token, user, RewardStore.UserTokenCursor({rewardPerToken: nextRewardPerTokenCursor, accruedReward: 0}));
        store.transferOut(token, receiver, accruedReward);

        emit RewardLogic__Claimed(user, receiver, nextRewardPerTokenCursor, accruedReward);

        return accruedReward;
    }

    error RewardLogic__NoClaimableAmount();
    error RewardLogic__UnacceptableTokenPrice(uint tokenPrice);
    error RewardLogic__InvalidClaimPrice();
    error RewardLogic__InvalidDuration();
    error RewardLogic__InvalidClaimToken();
    error RewardLogic__NotingToClaim();
}
