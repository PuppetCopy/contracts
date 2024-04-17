// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Precision} from "./../../utils/Precision.sol";
import {Router} from "../../utils/Router.sol";
import {RevenueDistributor2} from "./../RevenueDistributor2.sol";

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
        RevenueDistributor2 revenueDistributor;
        PuppetToken puppetToken;
        address revenueSource;
        uint rate;
    }

    struct CallExitConfig {
        Router router;
        Cugar cugar;
        Oracle oracle;
        RevenueDistributor2 revenueDistributor;
        PuppetToken puppetToken;
        address revenueSource;
        uint rate;
    }

    function getClaimableAmount(
        Cugar cugar, //
        uint rate,
        bytes32 cugarKey,
        uint tokenPrice,
        uint cugarAmount
    ) internal view returns (uint) {
        uint claimable = cugar.get(cugarKey);
        if (cugarAmount > claimable) revert RewardLogic__NotEnoughToClaim(claimable);
        uint maxClaimable = cugarAmount * 1e18 / tokenPrice;

        return Precision.applyBasisPoints(rate, maxClaimable);
    }

    function getClaimableAmount(
        Cugar cugar, //
        uint rate,
        IERC20 token,
        uint tokenPrice,
        address user,
        uint cugarAmount
    ) internal view returns (uint) {
        uint claimable = cugar.get(PositionUtils.getCugarKey(token, user));
        if (cugarAmount > claimable) revert RewardLogic__NotEnoughToClaim(claimable);
        uint maxClaimable = cugarAmount * 1e18 / tokenPrice;

        return Precision.applyBasisPoints(rate, maxClaimable);
    }

    function getLockRewardTimeMultiplier(VotingEscrow votingEscrow, address account, uint unlockTime) internal view returns (uint) {
        if (unlockTime == 0) unlockTime = votingEscrow.lockedEnd(account);

        uint maxTime = block.timestamp + MAXTIME;

        if (unlockTime >= maxTime) return Precision.BASIS_POINT_DIVISOR;

        return Precision.toBasisPoints(unlockTime, maxTime);
    }

    // state

    function lock(
        CallLockConfig memory callLockConfig,
        IERC20 revenueToken,
        address user,
        uint acceptableTokenPrice,
        uint unlockTime,
        uint cugarAmount
    ) internal {
        bytes32 cugarKey = PositionUtils.getCugarKey(revenueToken, user);

        uint maxPriceInRevenueToken = _syncPrice(callLockConfig.oracle, revenueToken, acceptableTokenPrice);
        uint lockTimeMultiplier = getLockRewardTimeMultiplier(callLockConfig.votingEscrow, user, unlockTime);
        uint claimableInToken = getClaimableAmount(callLockConfig.cugar, callLockConfig.rate, revenueToken, maxPriceInRevenueToken, user, cugarAmount);
        uint claimableInTokenAferLockMultiplier = Precision.applyBasisPoints(lockTimeMultiplier, claimableInToken);

        if (claimableInTokenAferLockMultiplier == 0) revert RewardLogic__NoClaimableAmount();

        callLockConfig.puppetToken.mint(address(this), claimableInTokenAferLockMultiplier);
        callLockConfig.votingEscrow.lock(address(this), user, claimableInTokenAferLockMultiplier, unlockTime);
        callLockConfig.cugar.distribute(callLockConfig.revenueDistributor, callLockConfig.revenueSource, cugarKey, revenueToken, cugarAmount);

        emit RewardLogic__ClaimOption(
            Choice.LOCK, callLockConfig.rate, cugarKey, user, revenueToken, maxPriceInRevenueToken, claimableInTokenAferLockMultiplier
        );
    }

    function exit(
        CallExitConfig memory callExitConfig, //
        IERC20 revenueToken,
        address user,
        uint acceptableTokenPrice,
        uint cugarAmount
    ) internal {
        bytes32 cugarKey = PositionUtils.getCugarKey(revenueToken, user);
        uint maxPriceInRevenueToken = _syncPrice(callExitConfig.oracle, revenueToken, acceptableTokenPrice);
        uint claimableInToken = getClaimableAmount(callExitConfig.cugar, callExitConfig.rate, revenueToken, maxPriceInRevenueToken, user, cugarAmount);

        callExitConfig.cugar.distribute(callExitConfig.revenueDistributor, callExitConfig.revenueSource, cugarKey, revenueToken, cugarAmount);
        callExitConfig.puppetToken.mint(user, claimableInToken);

        emit RewardLogic__ClaimOption(Choice.EXIT, callExitConfig.rate, cugarKey, user, revenueToken, maxPriceInRevenueToken, claimableInToken);
    }

    function _syncPrice(Oracle oracle, IERC20 token, uint acceptableTokenPrice) internal returns (uint maxPrice) {
        uint poolPrice = oracle.setPrimaryPrice();
        maxPrice = oracle.getMaxPrice(token, poolPrice);
        if (maxPrice > acceptableTokenPrice) revert RewardLogic__UnacceptableTokenPrice(maxPrice);
        if (maxPrice == 0) revert RewardLogic__InvalidClaimPrice();
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
    error RewardLogic__NotEnoughToClaim(uint claimable);
}
