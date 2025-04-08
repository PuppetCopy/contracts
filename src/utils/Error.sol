// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {GmxPositionUtils} from "../position/utils/GmxPositionUtils.sol";

library Error {
    // CallUtils
    error CallUtils__EmptyReceiver();
    error CallUtils__AddressEmptyCode(address target);
    error CallUtils__FailedInnerCall();
    error CallUtils__SafeERC20FailedOperation(address token);

    // TransferUtils
    error TransferUtils__EmptyTokenTranferGasLimit(IERC20 token);
    error TransferUtils__TokenTransferError(IERC20 token, address receiver, uint amount);
    error TransferUtils__EmptyHoldingAddress();

    event TransferUtils__TokenTransferReverted(string reason, bytes returndata);

    // Dictatorship
    error Dictatorship__ContractNotInitialized();
    error Dictatorship__ContractAlreadyInitialized();
    error Dictatorship__ConfigurationUpdateFailed();

    // BankStore
    error BankStore__InsufficientBalance();

    // VotingEscrow
    error VotingEscrow__Unsupported();

    // Core
    error CoreContract__Unauthorized(string contractName, string version);

    // RewardDistributor
    error RewardDistributor__InvalidAmount();
    error RewardDistributor__InsufficientRewards(uint accured);

    // VotingEscrowLogic
    error VotingEscrowLogic__ZeroAmount();
    error VotingEscrowLogic__ExceedMaxTime();
    error VotingEscrowLogic__ExceedingAccruedAmount(uint accured);

    error Access__CallerNotAuthority();
    error Access__Unauthorized();
    error Permission__Unauthorized();
    error Permission__CallerNotAuthority();

    // Stores
    error Store__InvalidLength();

    // PuppetStore
    error PuppetStore__OverwriteAllocation();

    // MatchRule
    error MatchRule__InvalidAllowanceRate(uint min, uint max);
    error MatchRule__TokenNotAllowed();
    error MatchRule__AllowanceAboveLimit(uint allowanceCap);
    error MatchRule__InvalidAmount();
    error MatchRule__InsufficientBalance();
    error MatchRule__InvalidActivityThrottle(uint minAllocationActivity, uint maxAllocationActivity);
    error MatchRule__InvalidExpiryDuration(uint minExpiryDuration);

    // MirrorPosition
    // --- Call Validation ---
    error MirrorPosition__InvalidAllocation();
    error MirrorPosition__InvalidAllocationOrFullyReduced();
    error MirrorPosition__InvalidCollateralDelta();
    error MirrorPosition__InvalidCurrentLeverage();
    error MirrorPosition__InvalidKeeperExeuctionFeeAmount();
    error MirrorPosition__InvalidKeeperExeuctionFeeReceiver();
    error MirrorPosition__InvalidSizeDelta();
    error MirrorPosition__PuppetListEmpty();
    error MirrorPosition__MaxPuppetList();
    error MirrorPosition__InvalidReceiver();
    error MirrorPosition__DustThresholdNotSet();
    error MirrorPosition__NoDustToCollect();
    error MirrorPosition__AmountExceedsDustThreshold();

    // --- State/Condition ---
    error MirrorPosition__AllocationAccountNotFound();
    error MirrorPosition__ExecuteOnZeroCollateralPosition();
    error MirrorPosition__ExecutionRequestMissing();
    error MirrorPosition__InitialMustBeIncrease();
    error MirrorPosition__NoAdjustmentRequired();
    error MirrorPosition__PositionNotFound();
    error MirrorPosition__TraderCollateralZero();
    error MirrorPosition__ZeroCollateralOnIncrease();
    error MirrorPosition__DustTransferFailed();

    // --- Fee/Fund ---
    error MirrorPosition__InsufficientSettledBalanceForKeeperFee();
    error MirrorPosition__InsufficientGmxExecutionFee();
    error MirrorPosition__KeeperAdjustmentExecutionFeeExceedsAllocatedAmount();
    error MirrorPosition__KeeperFeeExceedsCostFactor();
    error MirrorPosition__NoNetFundsAllocated();
    // --- External Interaction ---
    error MirrorPosition__OrderCreationFailed();
    error MirrorPosition__SettlementTransferFailed();

    // GmxExecutionCallback
    error GmxExecutionCallback__InvalidOrderType(GmxPositionUtils.OrderType orderType);

    // Subaccount
    error Subaccount__UnauthorizedOperator();
    error Subaccount__UnauthorizedCreator();
    error Subaccount__AlreadyInitialized();
    error Subaccount__OnlyFactory();

    // FeeMarketplace
    error FeeMarketplace__NotAuctionableToken();
    error FeeMarketplace__InsufficientUnlockedBalance(uint accruedReward);
    error FeeMarketplace__ZeroDeposit();

    // PuppetToken
    error PuppetToken__InvalidRate();
    error PuppetToken__ExceededRateLimit(uint rateLimit, uint emissionRate);
    error PuppetToken__CoreShareExceedsMining();
}
