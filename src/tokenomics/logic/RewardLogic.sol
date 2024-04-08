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
        Choice choice, uint rate, bytes32 cugarKey, address account, IERC20 token, uint poolPrice, uint priceInToken, uint amount
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

    function getClaimableAmount(Cugar cugar, uint rate, IERC20 token, uint price, address user) public view returns (uint) {
        uint revenueInToken = cugar.get(PositionUtils.getCugarKey(token, user));

        if (revenueInToken == 0) return 0;

        uint maxClaimable = (revenueInToken) * (price) / 1e48;
        return Precision.applyBasisPoints(maxClaimable, rate);
    }

    function getLockRewardTimeMultiplier(VotingEscrow votingEscrow, address account, uint unlockTime) public view returns (uint) {
        if (unlockTime == 0) unlockTime = votingEscrow.lockedEnd(account);

        uint maxTime = block.timestamp + MAXTIME;

        if (unlockTime >= maxTime) return Precision.BASIS_POINT_DIVISOR;

        return Precision.toBasisPoints(unlockTime, maxTime);
    }

    // state

    function lock(CallLockConfig memory callLockConfig, IERC20 revenueToken, address user, uint maxAcceptableTokenPrice, uint unlockTime) internal {
        bytes32 cugarKey = PositionUtils.getCugarKey(revenueToken, user);
        (uint poolPrice, uint priceInToken) = _syncPrice(callLockConfig.oracle, revenueToken, maxAcceptableTokenPrice);

        uint lockTimeMultiplier = getLockRewardTimeMultiplier(callLockConfig.votingEscrow, user, unlockTime);
        uint maxClaimableAmount = getClaimableAmount(callLockConfig.cugar, callLockConfig.rate, revenueToken, priceInToken, user);

        uint claimableAmount = Precision.applyBasisPoints(lockTimeMultiplier, maxClaimableAmount);
        if (claimableAmount == 0) revert RewardLogic__NoClaimableAmount();

        callLockConfig.puppetToken.mint(address(this), claimableAmount);
        callLockConfig.votingEscrow.lock(address(this), user, claimableAmount, unlockTime);
        callLockConfig.cugar.claimAndDistribute(
            callLockConfig.router, callLockConfig.revenueDistributor, cugarKey, callLockConfig.revenueSource, revenueToken, claimableAmount
        );

        emit RewardLogic__ClaimOption(Choice.LOCK, callLockConfig.rate, cugarKey, user, revenueToken, poolPrice, priceInToken, claimableAmount);
    }

    function exit(CallExitConfig memory callExitConfig, IERC20 revenueToken, address from, uint maxAcceptableTokenPrice) internal {
        bytes32 cugarKey = PositionUtils.getCugarKey(revenueToken, from);
        (uint poolPrice, uint priceInToken) = _syncPrice(callExitConfig.oracle, revenueToken, maxAcceptableTokenPrice);

        uint claimableAmount = getClaimableAmount(callExitConfig.cugar, callExitConfig.rate, revenueToken, priceInToken, from);
        if (claimableAmount == 0) revert RewardLogic__NoClaimableAmount();

        callExitConfig.puppetToken.mint(from, claimableAmount);
        callExitConfig.cugar.claimAndDistribute(
            callExitConfig.router, callExitConfig.revenueDistributor, cugarKey, callExitConfig.revenueSource, revenueToken, claimableAmount
        );

        emit RewardLogic__ClaimOption(Choice.EXIT, callExitConfig.rate, cugarKey, from, revenueToken, poolPrice, priceInToken, claimableAmount);
    }

    function _syncPrice(Oracle oracle, IERC20 token, uint maxAcceptableTokenPrice) internal returns (uint maxPrimaryPrice, uint priceInToken) {
        maxPrimaryPrice = oracle.getMaxPrimaryPrice(oracle.setPoolPrice());
        priceInToken = oracle.getSecondaryPrice(token, maxPrimaryPrice);
        if (priceInToken > maxAcceptableTokenPrice) revert RewardLogic__UnacceptableTokenPrice(priceInToken);
        if (priceInToken == 0) revert RewardLogic__InvalidClaimPrice();
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
