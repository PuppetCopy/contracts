// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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

    event RewardLogic__ClaimOption(Choice choice, uint rate, address user, IERC20 revenueToken, uint maxPriceInRevenueToken, uint rewardInToken);
    event RewardLogic__Claimed(address user, address receiver, uint fromCursor, uint toCursor, uint amount);

    struct CallOptionParmas {
        IERC20 revenueToken;
        address user;
        uint rate;
        uint acceptableTokenPrice;
        uint cugarAmount;
    }

    function getLockRewardTimeMultiplier(VotingEscrow votingEscrow, address user, uint unlockTime) internal view returns (uint) {
        if (unlockTime == 0) unlockTime = votingEscrow.getLock(user).end;

        uint maxTime = block.timestamp + MAXTIME;

        if (unlockTime >= maxTime) return Precision.BASIS_POINT_DIVISOR;

        return Precision.toBasisPoints(unlockTime, maxTime);
    }

    function getClaimableCursor(RewardStore store, IERC20 token, address user, uint cursor) internal view returns (uint) {
        (uint veSupply, uint cursorBalance, uint balance) = store.getUserCursorInfo(token, cursor, user);

        if (veSupply == 0) return 0;

        return balance * cursorBalance / veSupply;
    }

    function getClaimable(VotingEscrow votingEscrow, RewardStore store, IERC20 token, address user) internal view returns (uint amount) {
        uint toCursor = getCursor(block.timestamp);
        uint fromCursor = getUserTokenCursor(votingEscrow, store, token, user);

        return getClaimable(store, token, user, fromCursor, toCursor);
    }

    function getClaimable(RewardStore store, IERC20 token, address user, uint fromCursor, uint toCursor) internal view returns (uint amount) {
        if (fromCursor > toCursor) return 0;

        for (uint iCursor = fromCursor; iCursor < toCursor; iCursor += CURSOR_INTERVAL) {
            amount += getClaimableCursor(store, token, user, iCursor);
        }
    }

    function getUserTokenCursor(VotingEscrow votingEscrow, RewardStore store, IERC20 token, address user) internal view returns (uint) {
        uint fromCursor = store.getUserTokenCursor(token, user);
        if (fromCursor == 0) {
            return getCursor(votingEscrow.getUserPointHistory(user, 1).ts);
        }

        return fromCursor;
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
        uint maxClaimable = callParams.cugarAmount * 1e18 / maxPriceInRevenueToken;
        uint claimableInToken = Precision.applyBasisPoints(callParams.rate, maxClaimable);

        uint lockTimeMultiplier = getLockRewardTimeMultiplier(votingEscrow, callParams.user, unlockTime);
        uint claimableInTokenAferLockMultiplier = Precision.applyBasisPoints(lockTimeMultiplier, claimableInToken);

        if (claimableInTokenAferLockMultiplier == 0) revert RewardLogic__NoClaimableAmount();

        puppetToken.mint(address(this), claimableInTokenAferLockMultiplier);
        veLock(votingEscrow, store, address(this), callParams.user, claimableInTokenAferLockMultiplier, unlockTime);

        emit RewardLogic__ClaimOption(
            Choice.LOCK, callParams.rate, callParams.user, callParams.revenueToken, maxPriceInRevenueToken, claimableInTokenAferLockMultiplier
        );

        return claimableInTokenAferLockMultiplier;
    }

    function exit(
        RewardStore store, //
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

        emit RewardLogic__ClaimOption(
            Choice.EXIT, callParams.rate, callParams.user, callParams.revenueToken, maxPriceInRevenueToken, claimableInToken
        );

        return claimableInToken;
    }

    function veLock(
        VotingEscrow votingEscrow, //
        RewardStore store,
        address depositor,
        address user,
        uint tokenAmount,
        uint unlockTime
    ) internal {
        uint cursor = getCursor(block.timestamp);

        (VotingEscrow.Point memory point, VotingEscrow.Point memory nextUserPoint) = votingEscrow.lockFor(depositor, user, tokenAmount, unlockTime);
        store.setUserCursorBalance(cursor, user, getPointBalance(nextUserPoint, cursor));
        store.setCursorVeSupply(cursor, getPointBalance(point, cursor));

        VotingEscrow.Point memory userPoint = votingEscrow.getUserPoint(user);

        uint userCursor = getCursor(userPoint.ts + CURSOR_INTERVAL);

        for (uint iCursor = userCursor; iCursor < cursor; iCursor += CURSOR_INTERVAL) {
            store.setUserCursorBalance(iCursor, user, getPointBalance(userPoint, iCursor));
        }
    }

    function veWithdraw(VotingEscrow votingEscrow, RewardStore store, address user, address receiver) internal {
        votingEscrow.withdrawFor(user, receiver);

        // uint cursor = getCursor(block.timestamp);
        // store.setCursorVeSupply(cursor, 0);
    }

    function getPointBalance(VotingEscrow.Point memory point, uint cursor) internal pure returns (uint) {
        int dt = int(cursor) - int(point.ts);
        int bias = point.bias - point.slope * dt;
        return bias > 0 ? uint(bias) : 0;
    }

    function claim(VotingEscrow votingEscrow, RewardStore store, IERC20 token, address user, address receiver) internal returns (uint amount) {
        uint fromCursor = getUserTokenCursor(votingEscrow, store, token, user);
        uint toCursor = getCursor(block.timestamp);

        amount = getClaimable(store, token, user, fromCursor, toCursor);

        if (amount == 0) revert RewardLogic__NoClaimableAmount();
        if (toCursor > fromCursor) {
            store.setUserTokenCursor(token, user, toCursor);
        }

        emit RewardLogic__Claimed(user, receiver, fromCursor, toCursor, amount);
    }

    function claimAndTransfer(
        VotingEscrow votingEscrow, //
        RewardStore store,
        IERC20 token,
        address user,
        address receiver
    ) internal returns (uint amount) {
        amount = claim(votingEscrow, store, token, user, receiver);

        store.transferOut(token, receiver, amount);
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
