// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Precision} from "./../../utils/Precision.sol";

import {Cugar} from "./../../shared/Cugar.sol";
import {Oracle} from "./../Oracle.sol";
import {PuppetToken} from "../PuppetToken.sol";
import {IReferralStorage} from "./../../position/interface/IReferralStorage.sol";

import {VotingEscrow, MAXTIME} from "../VotingEscrow.sol";

library RewardLogic {
    enum Choice {
        LOCK,
        EXIT
    }

    event RewardLogic__ClaimOption(Choice choice, uint rate, address user, IERC20 revenueToken, uint maxPriceInRevenueToken, uint rewardInToken);
    event RewardLogic__ReferralOwnershipTransferred(address referralStorage, bytes32 code, address newOwner, uint timestamp);

    struct CallLockConfig {
        VotingEscrow votingEscrow;
        Oracle oracle;
        Cugar cugar;
        PuppetToken puppetToken;
        address revenueSource;
        uint rate;
    }

    struct CallExitConfig {
        Cugar cugar;
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

    // state

    function lock(
        CallLockConfig memory callLockConfig,
        IERC20 revenueToken,
        address user,
        uint acceptableTokenPrice,
        uint unlockTime,
        uint cugarAmount
    ) internal {
        uint maxPriceInRevenueToken = _syncPrice(callLockConfig.oracle, revenueToken, acceptableTokenPrice);
        uint maxClaimable = cugarAmount * 1e18 / maxPriceInRevenueToken;
        uint claimableInToken = Precision.applyBasisPoints(callLockConfig.rate, maxClaimable);

        uint lockTimeMultiplier = getLockRewardTimeMultiplier(callLockConfig.votingEscrow, user, unlockTime);
        uint claimableInTokenAferLockMultiplier = Precision.applyBasisPoints(lockTimeMultiplier, claimableInToken);

        if (claimableInTokenAferLockMultiplier == 0) revert RewardLogic__NoClaimableAmount();

        callLockConfig.puppetToken.mint(address(this), claimableInTokenAferLockMultiplier);
        callLockConfig.votingEscrow.lock(address(this), user, claimableInTokenAferLockMultiplier, unlockTime);
        callLockConfig.cugar.updateCursor(revenueToken, user, cugarAmount);

        emit RewardLogic__ClaimOption(
            Choice.LOCK, callLockConfig.rate, user, revenueToken, maxPriceInRevenueToken, claimableInTokenAferLockMultiplier
        );
    }

    function exit(
        CallExitConfig memory callExitConfig, //
        IERC20 revenueToken,
        address user,
        uint acceptableTokenPrice,
        uint cugarAmount
    ) internal {
        uint maxPriceInRevenueToken = _syncPrice(callExitConfig.oracle, revenueToken, acceptableTokenPrice);
        uint maxClaimable = cugarAmount * 1e18 / maxPriceInRevenueToken;
        uint claimableInToken = Precision.applyBasisPoints(callExitConfig.rate, maxClaimable);

        callExitConfig.cugar.updateCursor(revenueToken, user, cugarAmount);
        callExitConfig.puppetToken.mint(user, claimableInToken);

        emit RewardLogic__ClaimOption(Choice.EXIT, callExitConfig.rate, user, revenueToken, maxPriceInRevenueToken, claimableInToken);
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

    error RewardLogic__NoClaimableAmount();
    error RewardLogic__UnacceptableTokenPrice(uint tokenPrice);
    error RewardLogic__InvalidClaimPrice();
}
