// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {GmxPositionUtils} from "../position/utils/GmxPositionUtils.sol";

library Error {
    error CallUtils__EmptyReceiver();
    error CallUtils__AddressEmptyCode(address target);
    error CallUtils__FailedInnerCall();
    error CallUtils__SafeERC20FailedOperation(address token);

    error TransferUtils__EmptyTokenTranferGasLimit(IERC20 token);
    error TransferUtils__TokenTransferError(IERC20 token, address receiver, uint amount);
    error TransferUtils__EmptyHoldingAddress();

    event TransferUtils__TokenTransferReverted(string reason, bytes returndata);

    error Dictatorship__ContractNotInitialized();
    error Dictatorship__ContractAlreadyInitialized();
    error Dictatorship__ConfigurationUpdateFailed();

    error BankStore__InsufficientBalance();

    error VotingEscrow__Unsupported();

    error CoreContract__Unauthorized(string contractName, string version);

    error RewardDistributor__InvalidAmount();
    error RewardDistributor__InsufficientRewards(uint accured);

    error VotingEscrowLogic__ZeroAmount();
    error VotingEscrowLogic__ExceedMaxTime();
    error VotingEscrowLogic__ExceedingAccruedAmount(uint accured);

    error Access__CallerNotAuthority();
    error Access__Unauthorized();
    error Permission__Unauthorized();
    error Permission__CallerNotAuthority();

    error Store__InvalidLength();

    error PuppetStore__OverwriteAllocation();

    error MatchingRule__InvalidAllowanceRate(uint min, uint max);
    error MatchingRule__TokenNotAllowed();
    error MatchingRule__AllowanceAboveLimit(uint allowanceCap);
    error MatchingRule__InvalidAmount();
    error MatchingRule__InsufficientBalance();
    error MatchingRule__InvalidActivityThrottle(uint minAllocationActivity, uint maxAllocationActivity);
    error MatchingRule__InvalidExpiryDuration(uint minExpiryDuration);

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
    error MirrorPosition__AllocationAccountNotFound();
    error MirrorPosition__ExecuteOnZeroCollateralPosition();
    error MirrorPosition__ExecutionRequestMissing();
    error MirrorPosition__InitialMustBeIncrease();
    error MirrorPosition__NoAdjustmentRequired();
    error MirrorPosition__PositionNotFound();
    error MirrorPosition__TraderCollateralZero();
    error MirrorPosition__ZeroCollateralOnIncrease();
    error MirrorPosition__DustTransferFailed();
    error MirrorPosition__InsufficientSettledBalanceForKeeperFee();
    error MirrorPosition__InsufficientGmxExecutionFee();
    error MirrorPosition__KeeperAdjustmentExecutionFeeExceedsAllocatedAmount();
    error MirrorPosition__KeeperFeeExceedsCostFactor();
    error MirrorPosition__KeeperExecutionFeeNotFullyCovered();
    error MirrorPosition__PaymasterExecutionFeeNotFullyCovered(uint remaining);
    error MirrorPosition__NoNetFundsAllocated();

    error MirrorPosition__OrderCreationFailed();
    error MirrorPosition__SettlementTransferFailed();

    error GmxExecutionCallback__InvalidOrderType(GmxPositionUtils.OrderType orderType);

    error AllocationAccount__UnauthorizedOperator();
    error AllocationAccount__InsufficientBalance();

    error FeeMarketplace__NotAuctionableToken();
    error FeeMarketplace__InsufficientUnlockedBalance(uint accruedReward);
    error FeeMarketplace__ZeroDeposit();

    error PuppetToken__InvalidRate();
    error PuppetToken__ExceededRateLimit(uint rateLimit, uint emissionRate);
    error PuppetToken__CoreShareExceedsMining();
}
