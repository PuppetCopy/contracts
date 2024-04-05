// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {Precision} from "./../../utils/Precision.sol";
import {Router} from "../../utils/Router.sol";
import {VeRevenueDistributor} from "../VeRevenueDistributor.sol";

import {Cugar} from "./../../Cugar.sol";
import {PuppetToken} from "../PuppetToken.sol";

import {VotingEscrow, MAXTIME} from "../VotingEscrow.sol";

library RewardLogic {
    enum Choice {
        LOCK,
        EXIT
    }

    event RewardLogic__ClaimOption(Choice choice, address account, IERC20 token, uint amount);

    event RewardLogic__ReferralOwnershipTransferred(address referralStorage, bytes32 code, address newOwner, uint timestamp);

    struct CallLockConfig {
        VotingEscrow votingEscrow;
        Router router;
        Cugar cugar;
        VeRevenueDistributor revenueDistributor;
        PuppetToken puppetToken;
        uint rate;
    }

    struct CallExitConfig {
        Cugar cugar;
        VeRevenueDistributor revenueDistributor;
        PuppetToken puppetToken;
        uint rate;
    }

    function getClaimableAmount(uint distributionRatio, uint tokenAmount) public pure returns (uint) {
        return Precision.applyBasisPoints(tokenAmount, distributionRatio);
    }

    function getRewardTimeMultiplier(VotingEscrow votingEscrow, address account, uint unlockTime) public view returns (uint) {
        if (unlockTime == 0) {
            unlockTime = votingEscrow.lockedEnd(account);
        }

        uint maxTime = block.timestamp + MAXTIME;

        if (unlockTime >= maxTime) return Precision.BASIS_POINT_DIVISOR;

        return Precision.toBasisPoints(unlockTime, maxTime);
    }

    // state

    function lock(CallLockConfig memory callLockConfig, IERC20 revenueToken, uint maxAcceptableTokenPriceInUsdc, address from, uint unlockTime)
        internal
    {
        uint maxClaimableAmount = callLockConfig.cugar.claim(revenueToken, from, from, maxAcceptableTokenPriceInUsdc);
        if (maxClaimableAmount == 0) revert RewardLogic__NoClaimableAmount();

        uint claimableAmount = Precision.applyBasisPoints(
            getClaimableAmount(callLockConfig.rate, maxClaimableAmount), //
            getRewardTimeMultiplier(callLockConfig.votingEscrow, from, unlockTime)
        );

        callLockConfig.puppetToken.mint(address(this), claimableAmount);
        SafeERC20.forceApprove(callLockConfig.puppetToken, address(callLockConfig.router), claimableAmount);
        callLockConfig.votingEscrow.lock(address(this), from, claimableAmount, unlockTime);

        emit RewardLogic__ClaimOption(Choice.LOCK, from, revenueToken, claimableAmount);
    }

    function exit(CallExitConfig memory callExitConfig, IERC20 revenueToken, uint maxAcceptableTokenPriceInUsdc, address from) internal {
        uint maxClaimableAmount = callExitConfig.cugar.claim(revenueToken, from, from, maxAcceptableTokenPriceInUsdc);
        if (maxClaimableAmount == 0) revert RewardLogic__NoClaimableAmount();

        uint amount = getClaimableAmount(callExitConfig.rate, maxClaimableAmount);

        callExitConfig.puppetToken.mint(from, amount);

        emit RewardLogic__ClaimOption(Choice.EXIT, from, revenueToken, amount);
    }

    function claim(VeRevenueDistributor revenueDistributor, IERC20 token, address from, address to) internal {
        revenueDistributor.claim(token, from, to);
    }

    function claimList(VeRevenueDistributor revenueDistributor, IERC20[] calldata tokenList, address from, address to) internal {
        revenueDistributor.claimList(tokenList, from, to);
    }

    // governance

    // https://github.com/gmx-io/gmx-synthetics/blob/main/contracts/mock/ReferralStorage.sol#L127
    function transferReferralOwnership(address _referralStorage, bytes32 _code, address _newOwner) internal {
        bytes memory data = abi.encodeWithSignature("setCodeOwner(bytes32,address)", _code, _newOwner);
        (bool success,) = _referralStorage.call(data);

        if (!success) revert RewardLogic__TransferReferralFailed();

        emit RewardLogic__ReferralOwnershipTransferred(_referralStorage, _code, _newOwner, block.timestamp);
    }

    // internal view

    function getCugarKey(address account) internal pure returns (bytes32) {
        return keccak256(abi.encode("USER_REVENUE", account));
    }

    error RewardLogic__TransferReferralFailed();
    error RewardLogic__NoClaimableAmount();
    error RewardLogic__AdjustOtherLock();
}
