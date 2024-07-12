// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {Precision} from "./../../utils/Precision.sol";
import {Oracle} from "./../Oracle.sol";
import {PuppetToken} from "../PuppetToken.sol";

import {RewardStore} from "./../store/RewardStore.sol";

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
        uint rewardPerTokenCursor = store.getRewardPerTokenCursor(token) + Precision.toFactor(pendingEmission, getPointBias(point, point.ts));

        return getUserAccuredRewards(store, token, rewardPerTokenCursor, user, userPoint);
    }

    function getUserAccuredRewards(
        RewardStore store, //
        IERC20 token,
        uint rewardPerTokenCursor,
        address user,
        VotingEscrow.Point memory point
    ) internal view returns (uint) {
        RewardStore.UserTokenCursor memory userCursor = store.getUserTokenCursor(token, user);
        uint rewardDelta = rewardPerTokenCursor - userCursor.rewardPerToken;
        uint pendingReward = getPointBias(point, block.timestamp) * rewardDelta / Precision.FLOAT_PRECISION;

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

    function lock(
        VotingEscrow votingEscrow, //
        RewardStore store,
        Oracle oracle,
        PuppetToken puppetToken,
        CallOptionParmas memory callParams,
        uint unlockTime
    ) internal returns (uint) {
        store.decreaseUserSeedContribution(callParams.revenueToken, callParams.user, callParams.cugarAmount);

        uint maxPriceInRevenueToken = syncPrice(oracle, callParams.revenueToken, callParams.acceptableTokenPrice);
        uint claimableInTokenAferLockMultiplier = Precision.applyBasisPoints(
            getLockRewardTimeMultiplier(votingEscrow, callParams.user, unlockTime),
            Precision.applyBasisPoints(callParams.rate, callParams.cugarAmount * 1e18 / maxPriceInRevenueToken)
        );

        if (claimableInTokenAferLockMultiplier == 0) revert RewardLogic__NotingToContribute();

        puppetToken.mint(address(this), claimableInTokenAferLockMultiplier);
        (VotingEscrow.Point memory point, VotingEscrow.Point memory userPoint) = votingEscrow.getPoints(callParams.user);

        // VotingEscrow.Point memory userPoint = votingEscrow.getUserPoint(callParams.user);
        // (VotingEscrow.Point memory point,) = votingEscrow.lockFor(address(this), callParams.user, claimableInTokenAferLockMultiplier, unlockTime);
        // (VotingEscrow.Point memory point, VotingEscrow.Point memory userPoint) =
        //     votingEscrow.lockFor(address(this), callParams.user, claimableInTokenAferLockMultiplier, unlockTime);

        uint nextRewardPerTokenCursor = distribute(store, callParams.revenueToken, callParams.distributionTimeframe, callParams.revenueSource, point);
        uint accruedReward = getUserAccuredRewards(store, callParams.revenueToken, nextRewardPerTokenCursor, callParams.user, userPoint);

        store.setUserTokenCursor(
            callParams.revenueToken,
            callParams.user,
            RewardStore.UserTokenCursor({rewardPerToken: nextRewardPerTokenCursor, accruedReward: accruedReward})
        );

        votingEscrow.lockFor(address(this), callParams.user, claimableInTokenAferLockMultiplier, unlockTime);

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
        VotingEscrow.Point memory point = votingEscrow.getPoint();

        uint nextRewardPerTokenCursor = distribute(store, callParams.revenueToken, callParams.distributionTimeframe, callParams.revenueSource, point);
        uint maxPriceInRevenueToken = syncPrice(oracle, callParams.revenueToken, callParams.acceptableTokenPrice);
        uint maxClaimable = callParams.cugarAmount * 1e18 / maxPriceInRevenueToken;
        uint claimableInToken = Precision.applyBasisPoints(callParams.rate, maxClaimable);

        puppetToken.mint(receiver, claimableInToken);

        emit RewardLogic__Exit(callParams.user, callParams.revenueToken, maxPriceInRevenueToken, nextRewardPerTokenCursor, claimableInToken);

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
        (VotingEscrow.Point memory point, VotingEscrow.Point memory userPoint) = votingEscrow.getPoints(user);
        uint nextRewardPerTokenCursor = distribute(store, token, distributionTimeframe, revenueSource, point);
        uint accruedReward = getUserAccuredRewards(store, token, nextRewardPerTokenCursor, user, userPoint);

        if (accruedReward == 0) revert RewardLogic__NoClaimableAmount();

        store.setUserTokenCursor(token, user, RewardStore.UserTokenCursor({rewardPerToken: nextRewardPerTokenCursor, accruedReward: 0}));
        store.transferOut(token, receiver, accruedReward);

        emit RewardLogic__Claimed(user, receiver, nextRewardPerTokenCursor, accruedReward);

        return accruedReward;
    }

    function distribute(
        RewardStore store, //
        IERC20 token,
        uint distributionTimeframe,
        address source,
        VotingEscrow.Point memory point
    ) internal returns (uint) {
        uint lastTimestamp = store.getTokenEmissionTimestamp(token, source);
        uint rate = store.getTokenEmissionRate(token, source);
        uint sourceCommit = store.getSourceCommit(token, source);

        uint nextRate = sourceCommit / distributionTimeframe;
        uint timeElapsed = block.timestamp - lastTimestamp;

        if (timeElapsed > distributionTimeframe) {
            store.setTokenEmissionRate(token, source, 0);
        } else if (nextRate > rate) {
            rate = nextRate;
            store.setTokenEmissionRate(token, source, nextRate);
        }

        store.setTokenEmissionTimestamp(token, source, block.timestamp);

        // uint emission = sourceCommit;
        uint emission = Math.min(timeElapsed * rate, sourceCommit);

        if (emission == 0 || sourceCommit == 0 || rate == 0) {
            return store.getRewardPerTokenCursor(token);
        }

        store.decreaseSourceCommit(token, source, emission);
        store.transferIn(token, source, emission);

        uint rewardPerTokenDelta = Precision.toFactor(emission, getPointBias(point, point.ts));

        return store.increaseRewardPerTokenCursor(token, rewardPerTokenDelta);
    }

    function veWithdraw(VotingEscrow votingEscrow, RewardStore store, address user, address receiver) internal {
        votingEscrow.withdrawFor(user, receiver);
    }

    function getPointBias(VotingEscrow.Point memory point, uint time) internal pure returns (uint) {
        // return point.bias > 0 ? uint(point.bias) : 0;
        int dt = int(time) - int(point.ts);
        int bias = point.bias - point.slope * dt;
        return bias > 0 ? uint(bias) : 0;
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
    error RewardLogic__NotingToContribute();
}
