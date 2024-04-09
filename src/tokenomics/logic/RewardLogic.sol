// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Precision} from "./../../utils/Precision.sol";
import {Router} from "../../utils/Router.sol";
import {VeRevenueDistributor} from "../VeRevenueDistributor.sol";

import {Cugar} from "./../../shared/Cugar.sol";
import {Oracle} from "./../Oracle.sol";
import {PuppetToken} from "../PuppetToken.sol";
import {IReferralStorage} from "./../../position/interface/IReferralStorage.sol";
import {PositionUtils} from "./../../position/util/PositionUtils.sol";

import {VotingEscrow, MAXTIME} from "../VotingEscrow.sol";

library RewardLogic {
    enum Choice {
        LOCK,
        EXIT
    }

    event RewardLogic__ClaimOption(
        Choice choice, uint rate, bytes32 cugarKey, address account, IERC20 revenueToken, uint maxPriceInRevenueToken, uint rewardInToken
    );

    event RewardLogic__ReferralOwnershipTransferred(address referralStorage, bytes32 code, address newOwner, uint timestamp);

    struct CallLockConfig {
        Router router;
        VotingEscrow votingEscrow;
        Oracle oracle;
        Cugar cugar;
        VeRevenueDistributor revenueDistributor;
        PuppetToken puppetToken;
        address revenueSource;
        uint rate;
    }

    struct CallExitConfig {
        Router router;
        Cugar cugar;
        Oracle oracle;
        VeRevenueDistributor revenueDistributor;
        PuppetToken puppetToken;
        address revenueSource;
        uint rate;
    }

    function getClaimableAmountInToken(Cugar cugar, uint rate, IERC20 token, uint tokenPrice, address user) internal view returns (uint) {
        uint revenueInToken = cugar.get(PositionUtils.getCugarKey(token, user));

        if (revenueInToken == 0) return 0;

        uint maxClaimable = revenueInToken * Precision.FLOAT_PRECISION / tokenPrice;
        return Precision.applyBasisPoints(rate, maxClaimable);
    }

    function getLockRewardTimeMultiplier(VotingEscrow votingEscrow, address account, uint unlockTime) internal view returns (uint) {
        if (unlockTime == 0) unlockTime = votingEscrow.lockedEnd(account);

        uint maxTime = block.timestamp + MAXTIME;

        if (unlockTime >= maxTime) return Precision.BASIS_POINT_DIVISOR;

        return Precision.toBasisPoints(unlockTime, maxTime);
    }

    // state

    function lock(CallLockConfig memory callLockConfig, IERC20 revenueToken, address user, uint maxAcceptableTokenPrice, uint unlockTime) internal {
        bytes32 cugarKey = PositionUtils.getCugarKey(revenueToken, user);
        uint maxPriceInRevenueToken = _syncPrice(callLockConfig.oracle, revenueToken, maxAcceptableTokenPrice);

        uint lockTimeMultiplier = getLockRewardTimeMultiplier(callLockConfig.votingEscrow, user, unlockTime);
        uint claimableInToken = getClaimableAmountInToken(callLockConfig.cugar, callLockConfig.rate, revenueToken, maxPriceInRevenueToken, user);

        uint claimableInTokenAferLockMultiplier = Precision.applyBasisPoints(lockTimeMultiplier, claimableInToken);
        if (claimableInTokenAferLockMultiplier == 0) revert RewardLogic__NoClaimableAmount();

        callLockConfig.puppetToken.mint(address(this), claimableInTokenAferLockMultiplier);
        callLockConfig.votingEscrow.lock(address(this), user, claimableInTokenAferLockMultiplier, unlockTime);
        callLockConfig.cugar.claimAndDistribute(
            callLockConfig.router,
            callLockConfig.revenueDistributor,
            cugarKey,
            callLockConfig.revenueSource,
            revenueToken,
            claimableInTokenAferLockMultiplier
        );

        emit RewardLogic__ClaimOption(
            Choice.LOCK, callLockConfig.rate, cugarKey, user, revenueToken, maxPriceInRevenueToken, claimableInTokenAferLockMultiplier
        );
    }

    function exit(CallExitConfig memory callExitConfig, IERC20 revenueToken, address from, uint maxAcceptableTokenPrice) internal {
        bytes32 cugarKey = PositionUtils.getCugarKey(revenueToken, from);
        uint maxPriceInRevenueToken = _syncPrice(callExitConfig.oracle, revenueToken, maxAcceptableTokenPrice);

        uint claimableInToken = getClaimableAmountInToken(callExitConfig.cugar, callExitConfig.rate, revenueToken, maxPriceInRevenueToken, from);
        if (claimableInToken == 0) revert RewardLogic__NoClaimableAmount();

        callExitConfig.puppetToken.mint(from, claimableInToken);
        callExitConfig.cugar.claimAndDistribute(
            callExitConfig.router, callExitConfig.revenueDistributor, cugarKey, callExitConfig.revenueSource, revenueToken, claimableInToken
        );

        emit RewardLogic__ClaimOption(Choice.EXIT, callExitConfig.rate, cugarKey, from, revenueToken, maxPriceInRevenueToken, claimableInToken);
    }

    function _syncPrice(Oracle oracle, IERC20 token, uint maxAcceptableTokenPrice) internal returns (uint maxPrice) {
        uint poolPrice = oracle.setPrimaryPrice();
        maxPrice = oracle.getMaxPrice(token, poolPrice);
        if (maxPrice > maxAcceptableTokenPrice) revert RewardLogic__UnacceptableTokenPrice(maxPrice);
        if (maxPrice == 0) revert RewardLogic__InvalidClaimPrice();
    }

    function claim(VeRevenueDistributor revenueDistributor, IERC20 token, address from, address to) internal returns (uint) {
        return revenueDistributor.claim(token, from, to);
    }

    function claimList(VeRevenueDistributor revenueDistributor, IERC20[] calldata tokenList, address from, address to)
        internal
        returns (uint[] memory)
    {
        return revenueDistributor.claimList(tokenList, from, to);
    }

    // governance

    // https://github.com/gmx-io/gmx-synthetics/blob/main/contracts/mock/ReferralStorage.sol#L127
    function transferReferralOwnership(IReferralStorage _referralStorage, bytes32 _code, address _newOwner) internal {
        _referralStorage.setCodeOwner(_code, _newOwner);
    }

    // internal view

    function getCugarKey(address account) internal pure returns (bytes32) {
        return keccak256(abi.encode("USER_REVENUE", account));
    }

    error RewardLogic__NoClaimableAmount();
    error RewardLogic__UnacceptableTokenPrice(uint tokenPrice);
    error RewardLogic__InvalidClaimPrice();
}
