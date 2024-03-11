// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {Math} from "./../utils/Math.sol";

import {RewardStore} from "./store/RewardStore.sol";
import {Router} from "../utils/Router.sol";
import {PuppetToken} from "./PuppetToken.sol";
import {VotingEscrow, MAXTIME} from "./VotingEscrow.sol";
import {IVeRevenueDistributor} from "./../utils/interfaces/IVeRevenueDistributor.sol";

contract RewardLogic is Auth {
    enum Choice {
        LOCK,
        EXIT
    }

    event RewardLogic__ClaimOption(
        Choice choice,
        address indexed account,
        address dao,
        IERC20 revenueToken,
        uint revenueInToken,
        uint revenueInUsd,
        uint maxTokenAmount,
        uint rate,
        uint amount,
        uint daoRate,
        uint daoAmount
    );

    event RewardLogic__ReferralOwnershipTransferred(address referralStorage, bytes32 code, address newOwner, uint timestamp);

    struct OptionParams {
        RewardStore rewardStore;
        PuppetToken puppetToken;
        address dao;
        address account;
        IERC20 revenueToken;
        uint rate;
        uint daoRate;
        uint tokenPrice;
    }

    constructor(Authority _authority) Auth(address(0), _authority) {}

    function getClaimableAmount(uint distributionRatio, uint tokenAmount) public pure returns (uint) {
        uint claimableAmount = tokenAmount * distributionRatio / Math.BASIS_POINT_DIVISOR;
        return claimableAmount;
    }

    function getAccountGeneratedRevenue(RewardStore rewardStore, address account) public view returns (RewardStore.UserGeneratedRevenue memory) {
        return rewardStore.getUserGeneratedRevenue(getUserGeneratedRevenueKey(account));
    }

    function getRewardTimeMultiplier(VotingEscrow votingEscrow, address account, uint unlockTime) public view returns (uint) {
        if (unlockTime == 0) {
            unlockTime = votingEscrow.lockedEnd(account);
        }

        uint maxTime = block.timestamp + MAXTIME;

        if (unlockTime >= maxTime) return Math.BASIS_POINT_DIVISOR;

        return unlockTime * Math.BASIS_POINT_DIVISOR / maxTime;
    }

    // state

    function lock(Router router, VotingEscrow votingEscrow, OptionParams calldata params, uint unlockTime) public requiresAuth {
        RewardStore.UserGeneratedRevenue memory revenueInToken = getAccountGeneratedRevenue(params.rewardStore, params.account);
        uint maxRewardTokenAmount = revenueInToken.amountInUsd * 1e18 / params.tokenPrice;

        if (revenueInToken.amountInUsd == 0 || maxRewardTokenAmount == 0) revert RewardLogic__NoClaimableAmount();

        uint amount = getClaimableAmount(params.rate, maxRewardTokenAmount) * getRewardTimeMultiplier(votingEscrow, params.account, unlockTime)
            / Math.BASIS_POINT_DIVISOR;
        params.puppetToken.mint(address(this), amount);
        SafeERC20.forceApprove(params.puppetToken, address(router), amount);
        votingEscrow.lock(address(this), params.account, amount, unlockTime);

        uint daoAmount = getClaimableAmount(params.daoRate, maxRewardTokenAmount);
        params.puppetToken.mint(params.dao, daoAmount);

        resetUserRevenue(params.rewardStore, params.account);

        emit RewardLogic__ClaimOption(
            Choice.LOCK,
            params.account,
            params.dao,
            params.revenueToken,
            revenueInToken.amountInToken,
            revenueInToken.amountInUsd,
            maxRewardTokenAmount,
            params.rate,
            amount,
            params.daoRate,
            daoAmount
        );
    }

    function exit(OptionParams calldata params) public requiresAuth {
        RewardStore.UserGeneratedRevenue memory revenueInToken = getAccountGeneratedRevenue(params.rewardStore, params.account);

        uint maxRewardTokenAmount = revenueInToken.amountInUsd * 1e18 / params.tokenPrice;

        if (revenueInToken.amountInUsd == 0 || maxRewardTokenAmount == 0) revert RewardLogic__NoClaimableAmount();

        uint daoAmount = getClaimableAmount(params.daoRate, maxRewardTokenAmount);
        uint amount = getClaimableAmount(params.rate, maxRewardTokenAmount);

        params.puppetToken.mint(params.dao, daoAmount);
        params.puppetToken.mint(params.account, amount);

        resetUserRevenue(params.rewardStore, params.account);

        emit RewardLogic__ClaimOption(
            Choice.EXIT,
            params.account,
            params.dao,
            params.revenueToken,
            revenueInToken.amountInToken,
            revenueInToken.amountInUsd,
            maxRewardTokenAmount,
            params.rate,
            amount,
            params.daoRate,
            daoAmount
        );
    }

    function claim(IVeRevenueDistributor revenueDistributor, IERC20 revenueToken, address from, address to) public requiresAuth returns (uint) {
        return revenueDistributor.claim(revenueToken, from, to);
    }

    function setUserGeneratedRevenue(RewardStore rewardStore, address account, RewardStore.UserGeneratedRevenue calldata revenue)
        public
        requiresAuth
    {
        rewardStore.setUserGeneratedRevenue(getUserGeneratedRevenueKey(account), revenue);
    }

    // internal logic

    function resetUserRevenue(RewardStore rewardStore, address account) internal {
        rewardStore.removeUserGeneratedRevenue(getUserGeneratedRevenueKey(account));
    }

    // governance

    // https://github.com/gmx-io/gmx-synthetics/blob/main/contracts/mock/ReferralStorage.sol#L127
    function transferReferralOwnership(address _referralStorage, bytes32 _code, address _newOwner) external requiresAuth {
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
}
