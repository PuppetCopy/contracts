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
    event RewardLogic__ReferralOwnershipTransferred(address referralStorage, bytes32 code, address newOwner, uint timestamp);
    event RewardLogic__CheckpointToken(uint time, uint tokens);
    event RewardLogic__Claimed(address user, address receiver, uint fromCursor, uint toCursor, uint amount);

    struct CallLockConfig {
        Oracle oracle;
        PuppetToken puppetToken;
        address revenueSource;
        uint rate;
    }

    struct CallExitConfig {
        Oracle oracle;
        PuppetToken puppetToken;
        address revenueSource;
        uint rate;
    }

    function getLockRewardTimeMultiplier(VotingEscrow votingEscrow, address user, uint unlockTime) internal view returns (uint) {
        if (unlockTime == 0) unlockTime = votingEscrow.lockedEnd(user);

        uint maxTime = block.timestamp + MAXTIME;

        if (unlockTime >= maxTime) return Precision.BASIS_POINT_DIVISOR;

        return Precision.toBasisPoints(unlockTime, maxTime);
    }

    function getClaimableCursor(VotingEscrow votingEscrow, RewardStore store, IERC20 token, address user, uint cursor) internal view returns (uint) {
        uint balance = votingEscrow.balanceOf(user, cursor);

        if (balance == 0) return 0;

        (uint veSupply, uint cursorTokenBalance) = store.getCursorVeSupplyAndBalance(token, cursor);

        if (veSupply == 0) return 0;

        return balance * cursorTokenBalance / veSupply;
    }

    function getClaimable(VotingEscrow votingEscrow, RewardStore store, IERC20 token, address user) internal view returns (uint amount) {
        uint toCursor = getCursor(block.timestamp);
        uint fromCursor = getUserTokenCursor(votingEscrow, store, token, user);

        return getClaimable(votingEscrow, store, token, user, fromCursor, toCursor);
    }

    function getClaimable(VotingEscrow votingEscrow, RewardStore store, IERC20 token, address user, uint fromCursor, uint toCursor)
        internal
        view
        returns (uint amount)
    {
        if (fromCursor > toCursor) return 0;

        for (uint iCursor = fromCursor; iCursor < toCursor; iCursor += CURSOR_INTERVAL) {
            amount += getClaimableCursor(votingEscrow, store, token, user, iCursor);
        }
    }

    function getUserTokenCursor(VotingEscrow votingEscrow, RewardStore store, IERC20 token, address user) internal view returns (uint) {
        uint fromCursor = store.getUserTokenCursor(token, user);
        if (fromCursor == 0) {
            return getCursor(votingEscrow.userPointHistoryTs(user, 1));
        }

        return fromCursor;
    }

    // state

    function lock(
        VotingEscrow votingEscrow,
        RewardStore store,
        CallLockConfig memory callLockConfig,
        IERC20 revenueToken,
        address user,
        uint acceptableTokenPrice,
        uint unlockTime,
        uint cugarAmount
    ) internal returns (uint) {
        uint maxPriceInRevenueToken = syncPrice(callLockConfig.oracle, revenueToken, acceptableTokenPrice);
        uint maxClaimable = cugarAmount * 1e18 / maxPriceInRevenueToken;
        uint claimableInToken = Precision.applyBasisPoints(callLockConfig.rate, maxClaimable);

        uint lockTimeMultiplier = getLockRewardTimeMultiplier(votingEscrow, user, unlockTime);
        uint claimableInTokenAferLockMultiplier = Precision.applyBasisPoints(lockTimeMultiplier, claimableInToken);

        if (claimableInTokenAferLockMultiplier == 0) revert RewardLogic__NoClaimableAmount();

        callLockConfig.puppetToken.mint(address(this), claimableInTokenAferLockMultiplier);
        votingEscrow.lockFor(address(this), user, claimableInTokenAferLockMultiplier, unlockTime);
        contribute(votingEscrow, store, revenueToken, user, cugarAmount);

        emit RewardLogic__ClaimOption(
            Choice.LOCK, callLockConfig.rate, user, revenueToken, maxPriceInRevenueToken, claimableInTokenAferLockMultiplier
        );

        return claimableInTokenAferLockMultiplier;
    }

    function exit(
        VotingEscrow votingEscrow,
        RewardStore store,
        CallExitConfig memory callExitConfig, //
        IERC20 revenueToken,
        address user,
        uint acceptableTokenPrice,
        uint cugarAmount
    ) internal returns (uint) {
        contribute(votingEscrow, store, revenueToken, user, cugarAmount);
        uint maxPriceInRevenueToken = syncPrice(callExitConfig.oracle, revenueToken, acceptableTokenPrice);
        uint maxClaimable = cugarAmount * 1e18 / maxPriceInRevenueToken;
        uint claimableInToken = Precision.applyBasisPoints(callExitConfig.rate, maxClaimable);

        callExitConfig.puppetToken.mint(user, claimableInToken);

        emit RewardLogic__ClaimOption(Choice.EXIT, callExitConfig.rate, user, revenueToken, maxPriceInRevenueToken, claimableInToken);

        return claimableInToken;
    }

    function contribute(VotingEscrow votingEscrow, RewardStore store, IERC20 token, address user, uint amountInToken) internal {
        store.decreaseUserSeedContribution(token, user, amountInToken);

        uint cursor = getCursor(block.timestamp);
        uint veSupply = votingEscrow.totalSupply(cursor);
        votingEscrow.getLastPointHistory();
        store.setVeSupply(token, cursor, veSupply);
    }

    function claim(VotingEscrow votingEscrow, RewardStore store, IERC20 token, address user, address receiver) internal returns (uint amount) {
        uint fromCursor = getUserTokenCursor(votingEscrow, store, token, user);
        uint toCursor = getCursor(block.timestamp);

        amount = getClaimable(votingEscrow, store, token, user, fromCursor, toCursor);

        if (amount == 0) revert RewardLogic__NoClaimableAmount();
        if (toCursor > fromCursor) {
            store.setUserTokenCursor(token, user, toCursor);
        }

        store.transferOut(token, receiver, amount);

        emit RewardLogic__Claimed(user, receiver, fromCursor, toCursor, amount);
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
