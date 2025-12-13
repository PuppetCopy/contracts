// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.31;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

library Error {
    error TransferUtils__TokenTransferError(IERC20 token, address receiver, uint amount);
    error TransferUtils__TokenTransferFromError(IERC20 token, address from, address to, uint amount);
    error TransferUtils__EmptyHoldingAddress();
    error TransferUtils__SafeERC20FailedOperation(IERC20 token);
    error TransferUtils__InvalidReceiver();
    error TransferUtils__EmptyTokenTransferGasLimit(IERC20 token);

    error Dictatorship__ContractNotRegistered();
    error Dictatorship__ContractAlreadyInitialized();
    error Dictatorship__ConfigurationUpdateFailed();
    error Dictatorship__InvalidTargetAddress();
    error Dictatorship__InvalidCoreContract();

    error TokenRouter__EmptyTokenTranferGasLimit();

    error BankStore__InsufficientBalance();

    error PuppetVoteToken__Unsupported();

    error RewardDistributor__InvalidAmount();
    error RewardDistributor__InsufficientRewards(uint accured);

    error VotingEscrow__ZeroAmount();
    error VotingEscrow__ExceedMaxTime();
    error VotingEscrow__ExceedingAccruedAmount(uint accured);

    error Access__CallerNotAuthority();
    error Access__Unauthorized();

    error Permission__Unauthorized();
    error Permission__CallerNotAuthority();

    error Subscribe__InvalidAllowanceRate(uint min, uint max);
    error Subscribe__InvalidActivityThrottle(uint minAllocationActivity, uint maxAllocationActivity);
    error Subscribe__InvalidExpiryDuration(uint minExpiryDuration);

    error Mirror__InvalidAllocation(address allocationAddress);
    error Mirror__InvalidCollateralDelta();
    error Mirror__InvalidMatchmakerExecutionFeeAmount();
    error Mirror__InvalidExecutionFeeAmount();
    error Mirror__InvalidSizeDelta();
    error Mirror__PuppetListEmpty();
    error Mirror__PuppetListTooLarge(uint provided, uint maximum);
    error Mirror__InsufficientGmxExecutionFee(uint provided, uint required);
    error Mirror__MatchmakerFeeExceedsCostFactor(uint matchmakerFee, uint allocationAmount);
    error Mirror__OrderCreationFailed();
    error Mirror__MatchmakerFeeExceedsAdjustmentRatio(uint matchmakerFee, uint allocationAmount);
    error Mirror__MatchmakerFeeExceedsCloseRatio(uint matchmakerFee, uint allocationAmount);
    error Mirror__FeeExceedsCloseRatio(uint fee, uint allocationAmount);
    error Mirror__MatchmakerFeeNotFullyCovered(uint totalPaid, uint requiredFee);
    error Mirror__FeeNotFullyCovered(uint totalPaid, uint requiredFee);
    error Mirror__PuppetListMismatch(uint provided, uint expected);
    error Mirror__AllocationNotFullyRedistributed(uint remainingAllocation);
    error Mirror__RequestPending();
    error Mirror__NoPosition();
    error Mirror__PositionAlreadyOpen();
    error Mirror__DecreaseTooLarge(uint requested, uint available);
    error Mirror__TraderPositionTooOld();

    error Settle__InvalidAllocation(address allocationAddress);
    error Settle__PuppetListMismatch(uint provided, uint expected);
    error Settle__InvalidMatchmakerExecutionFeeAmount();
    error Settle__InvalidMatchmakerExecutionFeeReceiver();
    error Settle__MatchmakerFeeExceedsSettledAmount(uint matchmakerFee, uint settledAmount);
    error Settle__PuppetListExceedsMaximum(uint provided, uint maximum);
    error Settle__InvalidReceiver();
    error Settle__DustThresholdNotSet(address token);
    error Settle__NoDustToCollect(address token, address account);
    error Settle__AmountExceedsDustThreshold(uint amount, uint threshold);

    error Account__NoFundsToTransfer(address allocationAddress, address token);
    error Account__InvalidSettledAmount(IERC20 token, uint recordedAmount, uint settledAmount);
    error Account__InvalidAmount();
    error Account__TokenNotAllowed();
    error Account__DepositExceedsLimit(uint depositCap);
    error Account__InsufficientBalance(uint actualBalance, uint requiredAmount);
    error Account__ArrayLengthMismatch();
    error Account__InvalidDepositCap();
    error Account__InvalidTokenAddress();
    error Account__AmountExceedsUnaccounted();

    error AllocationAccount__UnauthorizedOperator();
    error AllocationAccount__InsufficientBalance();

    error MatchmakerRouter__FailedRefundExecutionFee();

    error FeeMarketplace__InsufficientUnlockedBalance(uint unlockedBalance);
    error FeeMarketplace__ZeroDeposit();
    error FeeMarketplace__InvalidConfig();
}
