// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/interfaces/IUniswapV3Pool.sol";
import {IVault} from "@balancer-labs/v2-interfaces/vault/IVault.sol";

import {Calc} from "./../utils/Calc.sol";
import {Router} from "../utils/Router.sol";
import {IVeRevenueDistributor} from "./../utils/interfaces/IVeRevenueDistributor.sol";

import {RewardStore} from "./store/RewardStore.sol";
import {OracleStore} from "./store/OracleStore.sol";

import {OracleLogic} from "./OracleLogic.sol";
import {PuppetToken} from "./PuppetToken.sol";
import {VotingEscrow, MAXTIME} from "./VotingEscrow.sol";

contract RewardLogic is Auth {
    enum Choice {
        LOCK,
        EXIT
    }

    event RewardLogic__ClaimOption(
        Choice choice,
        address indexed account,
        IERC20 revenueToken,
        uint revenueInToken,
        uint revenueInUsd,
        uint maxTokenAmount,
        uint amount,
        uint daoAmount
    );

    event RewardLogic__ReferralOwnershipTransferred(address referralStorage, bytes32 code, address newOwner, uint timestamp);

    struct CallStorePriceConfig {
        IUniswapV3Pool[] wntUsdPoolList;
        OracleStore oracleStore;
        OracleLogic oracleLogic;
        IVault vault;
        uint32 wntUsdTwapInterval;
        bytes32 poolId;
        uint maxAcceptableTokenPriceInUsdc;
    }

    struct CallLockConfig {
        Router router;
        VotingEscrow votingEscrow;
        RewardStore rewardStore;
        PuppetToken puppetToken;
        IERC20 revenueToken;
        uint rate;
        uint daoRate;
        address dao;
    }

    struct CallExitConfig {
        RewardStore rewardStore;
        PuppetToken puppetToken;
        IERC20 revenueToken;
        uint rate;
        uint daoRate;
        address dao;
    }

    struct CallClaimConfig {
        IVeRevenueDistributor revenueDistributor;
        IERC20 revenueToken;
    }

    struct CallVeConfig {
        VotingEscrow votingEscrow;
    }

    constructor(Authority _authority) Auth(address(0), _authority) {}

    function getClaimableAmount(uint distributionRatio, uint tokenAmount) public pure returns (uint) {
        uint claimableAmount = tokenAmount * distributionRatio / Calc.BASIS_POINT_DIVISOR;
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

        if (unlockTime >= maxTime) return Calc.BASIS_POINT_DIVISOR;

        return unlockTime * Calc.BASIS_POINT_DIVISOR / maxTime;
    }

    // state

    function lock(
        CallStorePriceConfig calldata callStorePriceConfig,
        CallLockConfig calldata callLockConfig,
        address from,
        uint maxAcceptableTokenPriceInUsdc,
        uint unlockTime
    ) external requiresAuth {
        uint tokenPrice = storePrice(callStorePriceConfig, maxAcceptableTokenPriceInUsdc);

        RewardStore.UserGeneratedRevenue memory revenueInToken = getAccountGeneratedRevenue(callLockConfig.rewardStore, from);
        uint maxRewardTokenAmount = revenueInToken.amountInUsd * 1e18 / tokenPrice;

        if (revenueInToken.amountInUsd == 0 || maxRewardTokenAmount == 0) revert RewardLogic__NoClaimableAmount();

        uint amount = getClaimableAmount(callLockConfig.rate, maxRewardTokenAmount)
            * getRewardTimeMultiplier(callLockConfig.votingEscrow, from, unlockTime) / Calc.BASIS_POINT_DIVISOR;
        callLockConfig.puppetToken.mint(address(this), amount);
        SafeERC20.forceApprove(callLockConfig.puppetToken, address(callLockConfig.router), amount);
        callLockConfig.votingEscrow.lock(address(this), from, amount, unlockTime);

        uint daoAmount = getClaimableAmount(callLockConfig.daoRate, maxRewardTokenAmount);
        callLockConfig.puppetToken.mint(callLockConfig.dao, daoAmount);

        resetUserGeneratedRevenue(callLockConfig.rewardStore, from);

        emit RewardLogic__ClaimOption(
            Choice.LOCK,
            from,
            callLockConfig.revenueToken,
            revenueInToken.amountInToken,
            revenueInToken.amountInUsd,
            maxRewardTokenAmount,
            amount,
            daoAmount
        );
    }

    function exit(
        CallStorePriceConfig calldata callStorePriceConfig,
        CallExitConfig calldata callParams,
        address from,
        uint maxAcceptableTokenPriceInUsdc
    ) external requiresAuth {
        uint tokenPrice = storePrice(callStorePriceConfig, maxAcceptableTokenPriceInUsdc);

        RewardStore.UserGeneratedRevenue memory revenueInToken = getAccountGeneratedRevenue(callParams.rewardStore, from);

        uint maxRewardTokenAmount = revenueInToken.amountInUsd * 1e18 / tokenPrice;

        if (revenueInToken.amountInUsd == 0 || maxRewardTokenAmount == 0) revert RewardLogic__NoClaimableAmount();

        uint daoAmount = getClaimableAmount(callParams.daoRate, maxRewardTokenAmount);
        uint amount = getClaimableAmount(callParams.rate, maxRewardTokenAmount);

        callParams.puppetToken.mint(callParams.dao, daoAmount);
        callParams.puppetToken.mint(from, amount);

        resetUserGeneratedRevenue(callParams.rewardStore, from);

        emit RewardLogic__ClaimOption(
            Choice.EXIT,
            from,
            callParams.revenueToken,
            revenueInToken.amountInToken,
            revenueInToken.amountInUsd,
            maxRewardTokenAmount,
            amount,
            daoAmount
        );
    }

    function claim(CallClaimConfig calldata callConfig, address from, address to) external requiresAuth returns (uint) {
        return callConfig.revenueDistributor.claim(callConfig.revenueToken, from, to);
    }

    function veLock(CallVeConfig calldata callConfig, address from, address to, uint tokenAmount, uint unlockTime) external requiresAuth {
        if (unlockTime > 0 && msg.sender != to) revert RewardLogic__AdjustOtherLock();

        callConfig.votingEscrow.lock(from, to, tokenAmount, unlockTime);
    }

    function veDeposit(CallVeConfig calldata callConfig, address from, uint value, address to) external requiresAuth {
        callConfig.votingEscrow.depositFor(from, to, value);
    }

    function veWithdraw(CallVeConfig calldata callConfig, address from, address to) external requiresAuth {
        callConfig.votingEscrow.withdraw(from, to);
    }

    function setUserGeneratedRevenue(RewardStore rewardStore, address account, RewardStore.UserGeneratedRevenue calldata revenue)
        public
        requiresAuth
    {
        rewardStore.setUserGeneratedRevenue(getUserGeneratedRevenueKey(account), revenue);
    }

    function storePrice(CallStorePriceConfig calldata callConfig, uint maxAcceptableTokenPriceInUsdc) public requiresAuth returns (uint tokenPrice) {
        tokenPrice = callConfig.oracleLogic.syncTokenPrice(
            callConfig.wntUsdPoolList, callConfig.vault, callConfig.oracleStore, callConfig.poolId, callConfig.wntUsdTwapInterval
        );

        if (tokenPrice > maxAcceptableTokenPriceInUsdc) revert RewardLogic__UnacceptableTokenPrice();
    }

    // internal

    function resetUserGeneratedRevenue(RewardStore rewardStore, address account) internal {
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
    error RewardLogic__UnacceptableTokenPrice();
    error RewardLogic__AdjustOtherLock();
}
