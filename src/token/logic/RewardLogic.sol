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
        uint totalSupply = votingEscrow.totalSupply();
        uint userBalance = getPointBias(votingEscrow.getUserPoint(user));
        uint pendingEmission = getPendingEmission(store, token, distributionTimeframe, source);
        uint rewardPerTokenCursor = store.getRewardPerTokenCursor(token) + Precision.toFactor(pendingEmission, totalSupply);

        RewardStore.UserTokenCursor memory userCursor = store.getUserTokenCursor(token, user);

        return userCursor.accruedReward + (userBalance * (rewardPerTokenCursor - userCursor.rewardPerToken) / Precision.FLOAT_PRECISION);
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
        store.decreaseUserSeedContribution(callParams.revenueToken, callParams.user, callParams.cugarAmount);

        uint maxPriceInRevenueToken = syncPrice(oracle, callParams.revenueToken, callParams.acceptableTokenPrice);

        uint claimableInTokenAferLockMultiplier = Precision.applyBasisPoints(
            getLockRewardTimeMultiplier(votingEscrow, callParams.user, unlockTime),
            Precision.applyBasisPoints(callParams.rate, callParams.cugarAmount * 1e18 / maxPriceInRevenueToken)
        );

        if (claimableInTokenAferLockMultiplier == 0) revert RewardLogic__NoClaimableAmount();

        puppetToken.mint(address(this), claimableInTokenAferLockMultiplier);

        uint rewardPerTokenCursor = distribute(
            votingEscrow, //
            store,
            callParams.revenueToken,
            callParams.distributionTimeframe,
            callParams.revenueSource
        );

        RewardStore.UserTokenCursor memory userCursor = store.getUserTokenCursor(callParams.revenueToken, callParams.user);
        uint accruedReward = votingEscrow.balanceOf(callParams.user) * (rewardPerTokenCursor - userCursor.rewardPerToken) / Precision.FLOAT_PRECISION;

        store.setUserTokenCursor(callParams.revenueToken, callParams.user, rewardPerTokenCursor, userCursor.accruedReward + accruedReward);
        votingEscrow.lockFor(address(this), callParams.user, claimableInTokenAferLockMultiplier, unlockTime);

        emit RewardLogic__Lock(
            callParams.user,
            callParams.revenueToken,
            maxPriceInRevenueToken,
            rewardPerTokenCursor,
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

        uint maxPriceInRevenueToken = syncPrice(oracle, callParams.revenueToken, callParams.acceptableTokenPrice);
        uint maxClaimable = callParams.cugarAmount * 1e18 / maxPriceInRevenueToken;
        uint claimableInToken = Precision.applyBasisPoints(callParams.rate, maxClaimable);

        puppetToken.mint(receiver, claimableInToken);

        uint rewardPerTokenCursor = distribute(
            votingEscrow, //
            store,
            callParams.revenueToken,
            callParams.distributionTimeframe,
            callParams.revenueSource
        );

        emit RewardLogic__Exit(callParams.user, callParams.revenueToken, maxPriceInRevenueToken, rewardPerTokenCursor, claimableInToken);

        return claimableInToken;
    }

    function distribute(
        VotingEscrow votingEscrow, //
        RewardStore store,
        IERC20 token,
        uint distributionTimeframe,
        address revenueSource
    ) internal returns (uint nextRewardPerTokenCursor) {
        uint totalSupply = votingEscrow.totalSupply();
        uint pendingEmission = store.emitReward(token, distributionTimeframe, revenueSource);
        nextRewardPerTokenCursor = store.getRewardPerTokenCursor(token) + Precision.toFactor(pendingEmission, totalSupply);
        store.setRewardPerTokenCursor(token, nextRewardPerTokenCursor);
    }

    function veWithdraw(VotingEscrow votingEscrow, RewardStore store, address user, address receiver) internal {
        votingEscrow.withdrawFor(user, receiver);
    }

    function getPointBias(VotingEscrow.Point memory point) internal pure returns (uint) {
        return point.bias > 0 ? uint(point.bias) : 0;
    }

    function getPointBias(VotingEscrow.Point memory point, uint time) internal pure returns (uint) {
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
        uint rewardPerTokenCursor = distribute(votingEscrow, store, token, distributionTimeframe, revenueSource);

        RewardStore.UserTokenCursor memory userCursor = store.getUserTokenCursor(token, user);
        uint userBalance = votingEscrow.balanceOf(user);
        uint accruedReward = userCursor.accruedReward + (userBalance * (rewardPerTokenCursor - userCursor.rewardPerToken) / Precision.FLOAT_PRECISION);

        store.setUserTokenCursor(token, user, rewardPerTokenCursor, 0);
        store.transferOut(token, receiver, accruedReward);

        emit RewardLogic__Claimed(user, receiver, rewardPerTokenCursor, accruedReward);

        return accruedReward;
    }

    function syncPrice(Oracle oracle, IERC20 token, uint acceptableTokenPrice) internal returns (uint maxPrice) {
        uint poolPrice = oracle.setPrimaryPrice();
        maxPrice = oracle.getMaxPrice(token, poolPrice);
        if (maxPrice > acceptableTokenPrice) revert RewardLogic__UnacceptableTokenPrice(maxPrice);
        if (maxPrice == 0) revert RewardLogic__InvalidClaimPrice();
    }

    function getCursor(uint _time) internal pure returns (uint) {
        return (_time / CURSOR_INTERVAL) * CURSOR_INTERVAL;
    }

    error RewardLogic__NoClaimableAmount();
    error RewardLogic__UnacceptableTokenPrice(uint tokenPrice);
    error RewardLogic__InvalidClaimPrice();
}
