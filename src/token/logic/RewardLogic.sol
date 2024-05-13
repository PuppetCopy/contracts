// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {Precision} from "./../../utils/Precision.sol";
import {Oracle} from "./../Oracle.sol";
import {PuppetToken} from "../PuppetToken.sol";

import {RewardStore, CURSOR_INTERVAL} from "./../store/RewardStore.sol";

import {VotingEscrow, MAXTIME} from "../VotingEscrow.sol";

library RewardLogic {
    enum Choice {
        LOCK,
        EXIT
    }

    event RewardLogic__Lock(
        address user,
        IERC20 revenueToken,
        uint maxPriceInRevenueToken,
        uint nextRewardPerTokenCursor,
        uint rewardInToken,
        uint accuredReward,
        uint unlockTime
    );
    event RewardLogic__Exit(address user, IERC20 revenueToken, uint maxPriceInRevenueToken, uint nextRewardPerTokenCursor, uint rewardInToken);

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

    function getLockRewardTimeMultiplier(VotingEscrow votingEscrow, address user, uint unlockTime) internal view returns (uint) {
        if (unlockTime == 0) unlockTime = votingEscrow.getLock(user).end;

        uint maxTime = block.timestamp + MAXTIME;

        if (unlockTime >= maxTime) return Precision.BASIS_POINT_DIVISOR;

        return Precision.toBasisPoints(unlockTime, maxTime);
    }

    function getClaimable(
        VotingEscrow votingEscrow, //
        RewardStore store,
        IERC20 token,
        address source,
        uint distributionTimeframe,
        address user
    ) internal view returns (uint) {
        (VotingEscrow.Point memory point, VotingEscrow.Point memory userPoint) = votingEscrow.getPoints(user);

        uint pendingEmission = getPendingEmission(store, token, distributionTimeframe, source);
        uint rewardPerTokenCursor = store.getRewardPerTokenCursor(token) + Precision.toFactor(pendingEmission, getPointBias(point, block.timestamp));

        return getUserAccuredRewards(store, token, rewardPerTokenCursor, user, userPoint);
    }

    function getUserAccuredRewards(RewardStore store, IERC20 token, uint rewardPerTokenCursor, address user, VotingEscrow.Point memory point)
        internal
        view
        returns (uint)
    {
        RewardStore.UserTokenCursor memory userCursor = store.getUserTokenCursor(token, user);
        uint userDeltaCursor = rewardPerTokenCursor - userCursor.rewardPerToken;

        return userCursor.accruedReward + getPointBias(point, block.timestamp) * userDeltaCursor / Precision.FLOAT_PRECISION;
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

        if (nextRate > rate || timeElapsed > distributionTimeframe) {
            rate = nextRate;
        }

        return Math.min(timeElapsed * nextRate, sourceCommit);
    }

    function lock(
        VotingEscrow votingEscrow, //
        RewardStore store,
        Oracle oracle,
        PuppetToken puppetToken,
        CallOptionParmas memory callParams,
        uint unlockTime
    ) internal returns (uint) {
        uint maxPriceInRevenueToken = syncPrice(oracle, callParams.revenueToken, callParams.acceptableTokenPrice);
        uint claimableInTokenAferLockMultiplier = Precision.applyBasisPoints(
            getLockRewardTimeMultiplier(votingEscrow, callParams.user, unlockTime),
            Precision.applyBasisPoints(callParams.rate, callParams.cugarAmount * 1e18 / maxPriceInRevenueToken)
        );

        if (claimableInTokenAferLockMultiplier == 0) revert RewardLogic__NoClaimableAmount();

        puppetToken.mint(address(this), claimableInTokenAferLockMultiplier);
        (VotingEscrow.Point memory point, VotingEscrow.Point memory userPoint) = votingEscrow.getPoints(callParams.user);
        votingEscrow.lockFor(address(this), callParams.user, claimableInTokenAferLockMultiplier, unlockTime);

        // (VotingEscrow.Point memory point, VotingEscrow.Point memory userPoint) =
        //     votingEscrow.lockFor(address(this), callParams.user, claimableInTokenAferLockMultiplier, unlockTime);

        store.decreaseUserSeedContribution(callParams.revenueToken, callParams.user, callParams.cugarAmount);

        uint nextRewardPerTokenCursor = distribute(store, callParams.revenueToken, callParams.distributionTimeframe, callParams.revenueSource, point);
        uint accruedReward = getUserAccuredRewards(store, callParams.revenueToken, nextRewardPerTokenCursor, callParams.user, userPoint);

        RewardStore.UserTokenCursor memory userCursor =
            RewardStore.UserTokenCursor({rewardPerToken: nextRewardPerTokenCursor, accruedReward: accruedReward});

        store.setUserTokenCursor(callParams.revenueToken, callParams.user, userCursor);

        emit RewardLogic__Lock(
            callParams.user,
            callParams.revenueToken,
            maxPriceInRevenueToken,
            nextRewardPerTokenCursor,
            claimableInTokenAferLockMultiplier,
            accruedReward,
            unlockTime
        );

        return claimableInTokenAferLockMultiplier;
    }

    function exit(
        VotingEscrow votingEscrow, //
        RewardStore store,
        Oracle oracle,
        PuppetToken puppetToken,
        CallOptionParmas memory callParams,
        address receiver
    ) internal returns (uint) {
        store.decreaseUserSeedContribution(callParams.revenueToken, callParams.user, callParams.cugarAmount);
        VotingEscrow.Point memory point = votingEscrow.getUserPoint(callParams.user);

        uint nextRewardPerTokenCursor = distribute(store, callParams.revenueToken, callParams.distributionTimeframe, callParams.revenueSource, point);
        uint maxPriceInRevenueToken = syncPrice(oracle, callParams.revenueToken, callParams.acceptableTokenPrice);
        uint maxClaimable = callParams.cugarAmount * 1e18 / maxPriceInRevenueToken;
        uint claimableInToken = Precision.applyBasisPoints(callParams.rate, maxClaimable);

        puppetToken.mint(receiver, claimableInToken);

        emit RewardLogic__Exit(callParams.user, callParams.revenueToken, maxPriceInRevenueToken, nextRewardPerTokenCursor, claimableInToken);

        return claimableInToken;
    }

    function distribute(RewardStore store, IERC20 token, uint distributionTimeframe, address source, VotingEscrow.Point memory point)
        internal
        returns (uint)
    {
        uint lastTimestamp = store.getTokenEmissionTimestamp(token, source);
        uint rate = store.getTokenEmissionRate(token, source);
        uint sourceCommit = store.getSourceCommit(token, source);

        uint nextRate = sourceCommit / distributionTimeframe;
        uint timeElapsed = block.timestamp - lastTimestamp;

        if (timeElapsed > distributionTimeframe) {
            store.setTokenEmissionTimestamp(token, source, block.timestamp);
            store.setTokenEmissionRate(token, source, nextRate);
        } else if (nextRate > rate) {
            rate = nextRate;
            store.setTokenEmissionRate(token, source, nextRate);
        }

        uint emission = Math.min(timeElapsed * rate, sourceCommit);

        store.decreaseSourceCommit(token, source, emission);
        store.transferIn(token, source, emission);

        return store.increaseRewardPerTokenCursor(token, Precision.toFactor(emission, getPointBias(point, block.timestamp)));
    }

    function veWithdraw(VotingEscrow votingEscrow, RewardStore store, address user, address receiver) internal {
        votingEscrow.withdrawFor(user, receiver);
    }

    function getPointBias(VotingEscrow.Point memory point) internal pure returns (uint) {
        // int dt = int(block.timestamp) - int(point.ts);
        // int bias = point.bias - point.slope * dt;
        // return bias > 0 ? uint(bias) : 0;
        return point.bias > 0 ? uint(point.bias) : 0;
    }

    function getPointBias(VotingEscrow.Point memory point, uint time) internal pure returns (uint) {
        // return getPointBias(point);
        int dt = int(time) - int(point.ts);
        int bias = point.bias - point.slope * dt;
        return bias > 0 ? uint(bias) : 0;
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
        (VotingEscrow.Point memory point, VotingEscrow.Point memory userPoint) = votingEscrow.getPoints(user);
        uint nextRewardPerTokenCursor = distribute(store, token, distributionTimeframe, revenueSource, point);
        uint accruedReward = getUserAccuredRewards(store, token, nextRewardPerTokenCursor, user, userPoint);

        RewardStore.UserTokenCursor memory userCursor = RewardStore.UserTokenCursor({rewardPerToken: nextRewardPerTokenCursor, accruedReward: 0});

        store.setUserTokenCursor(token, user, userCursor);
        store.transferOut(token, receiver, accruedReward);

        emit RewardLogic__Claimed(user, receiver, nextRewardPerTokenCursor, accruedReward);

        return accruedReward;
    }

    function syncPrice(Oracle oracle, IERC20 token, uint acceptableTokenPrice) internal returns (uint maxPrice) {
        uint poolPrice = oracle.setPrimaryPrice();
        maxPrice = oracle.getMaxPrice(token, poolPrice);
        if (maxPrice > acceptableTokenPrice) revert RewardLogic__UnacceptableTokenPrice(maxPrice);
        if (maxPrice == 0) revert RewardLogic__InvalidClaimPrice();
    }

    error RewardLogic__NoClaimableAmount();
    error RewardLogic__UnacceptableTokenPrice(uint tokenPrice);
    error RewardLogic__InvalidClaimPrice();
}
