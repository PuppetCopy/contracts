// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {Precision} from "./../../utils/Precision.sol";
import {Router} from "../../utils/Router.sol";
import {VeRevenueDistributor} from "../VeRevenueDistributor.sol";

import {UserGeneratedRevenueStore} from "../../shared/store/UserGeneratedRevenueStore.sol";
import {UserGeneratedRevenue} from "../../shared/UserGeneratedRevenue.sol";
import {PuppetToken} from "../PuppetToken.sol";
import {PositionUtils} from "../../position/util/PositionUtils.sol";

import {VotingEscrow, MAXTIME} from "../VotingEscrow.sol";

library RewardLogic {
    enum Choice {
        LOCK,
        EXIT
    }

    event RewardLogic__ClaimOption(
        Choice choice, address indexed account, UserGeneratedRevenueStore.Revenue[] revenueList, uint maxTokenAmount, uint amount
    );

    event RewardLogic__ReferralOwnershipTransferred(address referralStorage, bytes32 code, address newOwner, uint timestamp);

    struct CallLockConfig {
        VotingEscrow votingEscrow;
        Router router;
        UserGeneratedRevenueStore userGeneratedRevenueStore;
        UserGeneratedRevenue userGeneratedRevenue;
        VeRevenueDistributor revenueDistributor;
        PuppetToken puppetToken;
        uint rate;
    }

    struct CallExitConfig {
        UserGeneratedRevenueStore userGeneratedRevenueStore;
        UserGeneratedRevenue userGeneratedRevenue;
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

    function lock(CallLockConfig memory callLockConfig, IERC20[] calldata revTokenList, uint tokenPrice, address from, uint unlockTime) internal {
        bytes32[] memory keyList = new bytes32[](revTokenList.length);

        for (uint i = 0; i < revTokenList.length; i++) {
            keyList[i] = PositionUtils.getUserGeneratedRevenueKey(revTokenList[i], from, from);
        }

        (UserGeneratedRevenueStore.Revenue[] memory revenueList, uint totalClaimedInUsd) =
            callLockConfig.userGeneratedRevenue.claimUserGeneratedRevenueList(callLockConfig.userGeneratedRevenueStore, address(this), keyList);

        uint maxRewardTokenAmount = totalClaimedInUsd * 1e18 / tokenPrice;

        if (totalClaimedInUsd == 0 || maxRewardTokenAmount == 0) revert RewardLogic__NoClaimableAmount();

        uint amount = Precision.applyBasisPoints(
            getClaimableAmount(callLockConfig.rate, maxRewardTokenAmount), //
            getRewardTimeMultiplier(callLockConfig.votingEscrow, from, unlockTime)
        );
        callLockConfig.puppetToken.mint(address(this), amount);
        SafeERC20.forceApprove(callLockConfig.puppetToken, address(callLockConfig.router), amount);
        callLockConfig.votingEscrow.lock(address(this), from, amount, unlockTime);

        emit RewardLogic__ClaimOption(Choice.LOCK, from, revenueList, maxRewardTokenAmount, amount);
    }

    function exit(CallExitConfig memory callExitConfig, IERC20[] calldata tokenList, uint tokenPrice, address from) internal {
        bytes32[] memory keyList = new bytes32[](tokenList.length);

        for (uint i = 0; i < tokenList.length; i++) {
            keyList[i] = PositionUtils.getUserGeneratedRevenueKey(tokenList[i], from, from);
        }

        (UserGeneratedRevenueStore.Revenue[] memory revenueList, uint totalClaimedInUsd) =
            callExitConfig.userGeneratedRevenue.claimUserGeneratedRevenueList(callExitConfig.userGeneratedRevenueStore, address(this), keyList);

        uint maxRewardTokenAmount = totalClaimedInUsd * 1e18 / tokenPrice;

        if (totalClaimedInUsd == 0 || maxRewardTokenAmount == 0) revert RewardLogic__NoClaimableAmount();

        uint amount = getClaimableAmount(callExitConfig.rate, maxRewardTokenAmount);

        callExitConfig.puppetToken.mint(from, amount);

        emit RewardLogic__ClaimOption(Choice.EXIT, from, revenueList, maxRewardTokenAmount, amount);
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

    function getUserGeneratedRevenueKey(address account) internal pure returns (bytes32) {
        return keccak256(abi.encode("USER_REVENUE", account));
    }

    error RewardLogic__TransferReferralFailed();
    error RewardLogic__NoClaimableAmount();
    error RewardLogic__UnacceptableTokenPrice(uint curentPrice, uint acceptablePrice);
    error RewardLogic__AdjustOtherLock();
}
