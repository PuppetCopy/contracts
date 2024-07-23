// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {Precision} from "./../../utils/Precision.sol";
import {Oracle} from "./../Oracle.sol";
import {Puppet} from "../Puppet.sol";
import {RewardStore} from "./../store/RewardStore.sol";
import {VotingEscrow, MAXTIME} from "../VotingEscrow.sol";

library RewardLogic {
    enum Choice {
        LOCK,
        EXIT
    }

    event RewardLogic__Lock(address user, IERC20 revenueToken, uint maxPriceInRevenueToken, uint rewardInToken, uint accuredReward, uint unlockTime);
    event RewardLogic__Exit(address user, IERC20 revenueToken, uint maxPriceInRevenueToken, uint rewardInToken, uint accuredReward);

    event RewardLogic__Distribute(IERC20 revenueToken, address revenueSource, uint distributionTimeframe, uint supply, uint nextRewardPerTokenCursor);

    event RewardLogic__Claimed(address user, address receiver, uint rewardPerTokenCursor, uint amount);

    struct CallOptionParmas {
        IERC20 revenueToken;
        address revenueSource;
        address user;
        uint rate;
        uint distributionTimeframe;
        uint acceptableTokenPrice;
        uint cugarAmount;
    }

    function getClaimable(
        VotingEscrow votingEscrow, //
        RewardStore store,
        IERC20 token,
        address source,
        uint distributionTimeframe,
        address user
    ) internal view returns (uint) {
        uint pendingEmission = getPendingEmission(store, token, distributionTimeframe, source);
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
        uint distributionTimeframe,
        address source
    ) internal view returns (uint) {
        uint lastTimestamp = store.getTokenEmissionTimestamp(token, source);
        uint rate = store.getTokenEmissionRate(token, source);
        uint sourceCommit = store.getSourceCommit(token, source);

        uint nextRate = sourceCommit / distributionTimeframe;
        uint timeElapsed = block.timestamp - lastTimestamp;

        if (nextRate > rate) {
            rate = nextRate;
        }

        return Math.min(timeElapsed * nextRate, sourceCommit);
    }

    function distribute(
        RewardStore store, //
        IERC20 token,
        address source,
        uint distributionTimeframe,
        uint supply
    ) internal returns (uint) {
        uint timeElapsed = block.timestamp - store.getTokenEmissionTimestamp(token, source);
        uint rate = store.getTokenEmissionRate(token, source);
        uint sourceCommit = store.getSourceCommit(token, source);
        uint nextRate = sourceCommit / distributionTimeframe;

        if (timeElapsed > distributionTimeframe) {
            store.setTokenEmissionRate(token, source, 0);
        } else if (nextRate > rate) {
            rate = nextRate;
            store.setTokenEmissionRate(token, source, nextRate);
        }

        store.setTokenEmissionTimestamp(token, source, block.timestamp);

        uint emission = Math.min(timeElapsed * rate, sourceCommit);

        if (emission == 0 || sourceCommit == 0) {
            return store.getRewardPerTokenCursor(token);
        }

        store.decreaseSourceCommit(token, source, emission);
        store.transferIn(token, source, emission);

        uint rewardPerToken = store.increaseRewardPerTokenCursor(token, Precision.toFactor(emission, supply));

        emit RewardLogic__Distribute(token, source, distributionTimeframe, supply, rewardPerToken);

        return rewardPerToken;
    }

    function distributeUser(
        VotingEscrow votingEscrow, //
        RewardStore store,
        IERC20 token,
        address source,
        uint distributionTimeframe,
        address user
    ) internal returns (uint) {
        uint nextRewardPerTokenCursor = distribute(store, token, source, distributionTimeframe, votingEscrow.totalSupply());
        uint accruedReward = getUserAccuredRewards(store, token, user, nextRewardPerTokenCursor, votingEscrow.balanceOf(user));

        store.setUserTokenCursor(token, user, RewardStore.UserTokenCursor({rewardPerToken: nextRewardPerTokenCursor, accruedReward: accruedReward}));

        return accruedReward;
    }

    function veWithdraw(VotingEscrow votingEscrow, address user, address receiver, uint amount) internal {
        votingEscrow.withdraw(user, receiver, amount);
    }

    function syncPrice(Oracle oracle, IERC20 token, uint acceptableTokenPrice) internal returns (uint maxPrice) {
        uint poolPrice = oracle.setPrimaryPrice();
        maxPrice = oracle.getMaxPrice(token, poolPrice);
        if (maxPrice > acceptableTokenPrice) revert RewardLogic__UnacceptableTokenPrice(maxPrice);
        if (maxPrice == 0) revert RewardLogic__InvalidClaimPrice();
    }

    function lock(
        VotingEscrow votingEscrow, //
        RewardStore store,
        Oracle oracle,
        Puppet puppetToken,
        CallOptionParmas memory callParams,
        uint unlockDuration
    ) internal returns (uint) {
        if (unlockDuration > MAXTIME) revert RewardLogic__InvalidDuration();

        store.decreaseUserSeedContribution(callParams.revenueToken, callParams.user, callParams.cugarAmount);

        uint maxPriceInRevenueToken = syncPrice(oracle, callParams.revenueToken, callParams.acceptableTokenPrice);
        uint claimableInTokenAferLockMultiplier = Precision.applyBasisPoints(
            Precision.toBasisPoints(unlockDuration, MAXTIME),
            Precision.applyBasisPoints(callParams.rate, callParams.cugarAmount * 1e18 / maxPriceInRevenueToken)
        );

        if (claimableInTokenAferLockMultiplier == 0) revert RewardLogic__NotingToContribute();

        puppetToken.mint(address(this), claimableInTokenAferLockMultiplier);

        uint accruedReward = distributeUser(
            votingEscrow,
            store, //
            callParams.revenueToken,
            callParams.revenueSource,
            callParams.distributionTimeframe,
            callParams.user
        );

        votingEscrow.lock(address(this), callParams.user, claimableInTokenAferLockMultiplier, unlockDuration);

        emit RewardLogic__Lock(
            callParams.user, callParams.revenueToken, maxPriceInRevenueToken, claimableInTokenAferLockMultiplier, accruedReward, unlockDuration
        );

        return claimableInTokenAferLockMultiplier;
    }

    function exit(
        VotingEscrow votingEscrow, //
        RewardStore store,
        Oracle oracle,
        Puppet puppetToken,
        CallOptionParmas memory callParams,
        address receiver
    ) internal returns (uint) {
        store.decreaseUserSeedContribution(callParams.revenueToken, callParams.user, callParams.cugarAmount);

        uint accuredReward = distributeUser(
            votingEscrow, //
            store,
            callParams.revenueToken,
            callParams.revenueSource,
            callParams.distributionTimeframe,
            callParams.user
        );
        uint maxPriceInRevenueToken = syncPrice(oracle, callParams.revenueToken, callParams.acceptableTokenPrice);
        uint claimableInToken = Precision.applyBasisPoints(callParams.rate, callParams.cugarAmount * 1e18 / maxPriceInRevenueToken);

        puppetToken.mint(receiver, claimableInToken);

        emit RewardLogic__Exit(callParams.user, callParams.revenueToken, maxPriceInRevenueToken, claimableInToken, accuredReward);

        return claimableInToken;
    }

    function claim(
        VotingEscrow votingEscrow,
        RewardStore store,
        IERC20 token,
        uint distributionTimeframe,
        address revenueSource,
        address user,
        address receiver
    ) internal returns (uint) {
        uint nextRewardPerTokenCursor = distribute(store, token, revenueSource, distributionTimeframe, votingEscrow.totalSupply());
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
    error RewardLogic__NotingToContribute();
}
