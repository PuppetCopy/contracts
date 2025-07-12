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

    error RewardDistributor__InvalidAmount();
    error RewardDistributor__InsufficientRewards(uint accured);

    error VotingEscrow__ZeroAmount();
    error VotingEscrow__ExceedMaxTime();
    error VotingEscrow__ExceedingAccruedAmount(uint accured);

    error Access__CallerNotAuthority();
    error Access__Unauthorized();

    error Permission__Unauthorized();
    error Permission__CallerNotAuthority();

    error MatchingRule__InvalidAllowanceRate(uint min, uint max);
    error MatchingRule__TokenNotAllowed();
    error MatchingRule__AllowanceAboveLimit(uint allowanceCap);
    error MatchingRule__InvalidAmount();
    error MatchingRule__InsufficientBalance();
    error MatchingRule__InvalidActivityThrottle(uint minAllocationActivity, uint maxAllocationActivity);
    error MatchingRule__InvalidExpiryDuration(uint minExpiryDuration);

    error MirrorPosition__InvalidAllocation(address allocationAddress);
    error MirrorPosition__InvalidAllocationId();
    error MirrorPosition__InvalidSettledAmount(IERC20 token, uint recordedAmount, uint settledAmount);
    error MirrorPosition__InvalidCollateralDelta();
    error MirrorPosition__InvalidCurrentLeverage();
    error MirrorPosition__InvalidKeeperExecutionFeeAmount();
    error MirrorPosition__InvalidKeeperExecutionFeeReceiver();
    error MirrorPosition__InvalidSizeDelta();
    error MirrorPosition__PuppetListEmpty();
    error MirrorPosition__PuppetListExceedsMaximum(uint provided, uint maximum);
    error MirrorPosition__InvalidReceiver();
    error MirrorPosition__DustThresholdNotSet(address token);
    error MirrorPosition__NoDustToCollect(address token, address account);
    error MirrorPosition__AmountExceedsDustThreshold(uint amount, uint threshold);
    error MirrorPosition__ExecutionRequestMissing(bytes32 requestKey);
    error MirrorPosition__InitialMustBeIncrease();
    error MirrorPosition__NoAdjustmentRequired();
    error MirrorPosition__PositionNotFound(address allocationAddress);
    error MirrorPosition__TraderCollateralZero(address allocationAddress);
    error MirrorPosition__DustTransferFailed(address token, address account);
    error MirrorPosition__InsufficientGmxExecutionFee(uint provided, uint required);
    error MirrorPosition__InsufficientAllocationForKeeperFee(uint allocation, uint keeperFee);
    error MirrorPosition__KeeperFeeExceedsCostFactor(uint keeperFee, uint allocationAmount);
    error MirrorPosition__OrderCreationFailed();
    error MirrorPosition__SettlementTransferFailed(address token, address account);
    error MirrorPosition__KeeperExecutionFeeNotFullyCovered();
    error MirrorPosition__KeeperFeeExceedsSettledAmount(uint keeperFee, uint settledAmount);

    error Allocation__InvalidAllocation(address allocationAddress);
    error Allocation__InvalidKeeperExecutionFeeAmount();
    error Allocation__InvalidKeeperExecutionFeeReceiver();
    error Allocation__KeeperFeeExceedsAdjustmentRatio(uint keeperFee, uint allocationAmount);
    error Allocation__KeeperFeeExceedsCostFactor(uint keeperFee, uint allocationAmount);
    error Allocation__KeeperFeeExceedsSettledAmount(uint keeperFee, uint settledAmount);
    error Allocation__PuppetListEmpty();
    error Allocation__PuppetListExceedsMaximum(uint provided, uint maximum);
    error Allocation__PuppetListMismatch(uint expected, uint provided);
    error Allocation__InvalidReceiver();
    error Allocation__InvalidSettledAmount(IERC20 token, uint recordedAmount, uint settledAmount);
    error Allocation__SettlementTransferFailed(address token, address account);
    error Allocation__DustThresholdNotSet(address token);
    error Allocation__NoDustToCollect(address token, address account);
    error Allocation__AmountExceedsDustThreshold(uint amount, uint threshold);
    error Allocation__DustTransferFailed(address token, address account);

    error GmxExecutionCallback__FailedRefundExecutionFee();

    error AllocationAccount__UnauthorizedOperator();
    error AllocationAccount__InsufficientBalance();

    error FeeMarketplace__NotAuctionableToken();
    error FeeMarketplace__InsufficientUnlockedBalance(uint accruedReward);
    error FeeMarketplace__ZeroDeposit();
    error FeeMarketplace__InvalidReceiver();
    error FeeMarketplace__InvalidAmount();
    error FeeMarketplace__InsufficientDistributionBalance(uint requested, uint available);
}
