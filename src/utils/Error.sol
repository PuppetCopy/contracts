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

    error Dictatorship__ContractNotRegistered();
    error Dictatorship__ContractAlreadyInitialized();
    error Dictatorship__CoreContractInitConfigNotSet();
    error Dictatorship__InvalidUserAddress();
    error Dictatorship__ConfigurationUpdateFailed();
    error Dictatorship__InvalidTargetAddress();
    error Dictatorship__EmptyConfiguration();
    error Dictatorship__CoreContractConfigCallFailed();
    error Dictatorship__InvalidCoreContract();

    error Permission__InvalidFunctionSignature();

    error TokenRouter__EmptyTokenTranferGasLimit();
    error BankStore__InsufficientBalance();

    error PuppetVoteToken__Unsupported();

    error CoreContract__Unauthorized(string contractName, string version);
    error CoreContract__ConfigurationNotSet();

    error RewardDistributor__InvalidAmount();
    error RewardDistributor__InsufficientRewards(uint accured);

    error VotingEscrow__ZeroAmount();
    error VotingEscrow__ExceedMaxTime();
    error VotingEscrow__ExceedingAccruedAmount(uint accured);

    error Access__CallerNotAuthority();
    error Access__Unauthorized();

    error Permission__Unauthorized();
    error Permission__CallerNotAuthority();

    error PuppetStore__OverwriteAllocation();

    error MatchingRule__InvalidAllowanceRate(uint min, uint max);
    error MatchingRule__TokenNotAllowed();
    error MatchingRule__AllowanceAboveLimit(uint allowanceCap);
    error MatchingRule__InvalidAmount();
    error MatchingRule__InsufficientBalance();
    error MatchingRule__InvalidActivityThrottle(uint minAllocationActivity, uint maxAllocationActivity);
    error MirrorPosition__InvalidAllocation();
    error MatchingRule__InvalidExpiryDuration(uint minExpiryDuration);
    error MirrorPosition__InvalidAllocationId();
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
    error MirrorPosition__KeeperFeeExceedsCostFactor(uint keeperFee, uint allocationAmount);
    error MirrorPosition__OrderCreationFailed();
    error MirrorPosition__SettlementTransferFailed();
    error MirrorPosition__KeeperExecutionFeeNotFullyCovered();
    error MirrorPosition__PaymasterExecutionFeeNotFullyCovered(uint remaining);

    error GmxExecutionCallback__InvalidOrderType(GmxPositionUtils.OrderType orderType);
    error GmxExecutionCallback__FailedRefundExecutionFee();

    error AllocationAccount__UnauthorizedOperator();
    error AllocationAccount__InsufficientBalance();

    error FeeMarketplace__NotAuctionableToken();
    error FeeMarketplace__InsufficientUnlockedBalance(uint accruedReward);
    error FeeMarketplace__ZeroDeposit();

    error PuppetToken__InvalidRate();
    error PuppetToken__ExceededRateLimit(uint rateLimit, uint emissionRate);
    error PuppetToken__CoreShareExceedsMining();
}
