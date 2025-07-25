// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

library Error {
    error TransferUtils__TokenTransferError(IERC20 token, address receiver, uint amount);
    error TransferUtils__TokenTransferFromError(IERC20 token, address from, address to, uint amount);
    error TransferUtils__EmptyHoldingAddress();
    error TransferUtils__SafeERC20FailedOperation(IERC20 token);
    error TransferUtils__InvalidReceiver();
    error TransferUtils__EmptyTokenTransferGasLimit(IERC20 token);

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

    error Rule__InvalidAllowanceRate(uint min, uint max);
    error Rule__InvalidActivityThrottle(uint minAllocationActivity, uint maxAllocationActivity);
    error Rule__InvalidExpiryDuration(uint minExpiryDuration);

    error Deposit__TokenNotAllowed();
    error Deposit__AllowanceAboveLimit(uint allowanceCap);
    error Deposit__InvalidAmount();
    error Deposit__InsufficientBalance();

    error Mirror__InvalidAllocation(address allocationAddress);
    error Mirror__InvalidAllocationId();
    error Mirror__InvalidSettledAmount(IERC20 token, uint recordedAmount, uint settledAmount);
    error Mirror__InvalidCollateralDelta();
    error Mirror__InvalidCurrentLeverage();
    error Mirror__InvalidKeeperExecutionFeeAmount();
    error Mirror__InvalidKeeperExecutionFeeReceiver();
    error Mirror__InvalidSizeDelta();
    error Mirror__PuppetListEmpty();
    error Mirror__PuppetListExceedsMaximum(uint provided, uint maximum);
    error Mirror__InvalidReceiver();
    error Mirror__DustThresholdNotSet(address token);
    error Mirror__NoDustToCollect(address token, address account);
    error Mirror__AmountExceedsDustThreshold(uint amount, uint threshold);
    error Mirror__ExecutionRequestMissing(bytes32 requestKey);
    error Mirror__InitialMustBeIncrease();
    error Mirror__NoAdjustmentRequired();
    error Mirror__PositionNotFound(address allocationAddress);
    error Mirror__PositionNotStalled(address allocationAddress, bytes32 positionKey);
    error Mirror__TraderCollateralZero(address allocationAddress);
    error Mirror__DustTransferFailed(address token, address account);
    error Mirror__InsufficientGmxExecutionFee(uint provided, uint required);
    error Mirror__InsufficientAllocationForKeeperFee(uint allocation, uint keeperFee);
    error Mirror__KeeperFeeExceedsCostFactor(uint keeperFee, uint allocationAmount);
    error Mirror__OrderCreationFailed();
    error Mirror__SettlementTransferFailed(address token, address account);
    error Mirror__KeeperExecutionFeeNotFullyCovered();
    error Mirror__KeeperFeeExceedsSettledAmount(uint keeperFee, uint settledAmount);

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
    error Allocation__InsufficientFundsForKeeperFee(uint puppetIndex, uint unpaidAmount, uint puppetAllocation);
    error Allocation__KeeperFeeNotFullyCovered(uint totalPaid, uint requiredFee);
    error Allocation__InsufficientAllocationForKeeperFee(uint allocation, uint keeperFee);

    error AllocationAccount__UnauthorizedOperator();
    error AllocationAccount__InsufficientBalance();

    error KeeperRouter__FailedRefundExecutionFee();

    error FeeMarketplace__NotAuctionableToken();
    error FeeMarketplace__InsufficientUnlockedBalance(uint accruedReward);
    error FeeMarketplace__ZeroDeposit();
    error FeeMarketplace__InvalidReceiver();
    error FeeMarketplace__InvalidAmount();
    error FeeMarketplace__InsufficientDistributionBalance(uint requested, uint available);
}
