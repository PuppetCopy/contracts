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

    error Rule__InvalidAllowanceRate(uint min, uint max);
    error Rule__InvalidActivityThrottle(uint minAllocationActivity, uint maxAllocationActivity);
    error Rule__InvalidExpiryDuration(uint minExpiryDuration);

    error Mirror__InvalidAllocation(address allocationAddress);
    error Mirror__TraderPositionNotFound(address trader, bytes32 positionKey);
    error Mirror__InvalidCollateralDelta();
    error Mirror__InvalidCurrentLeverage();
    error Mirror__InvalidKeeperExecutionFeeAmount();
    error Mirror__InvalidSizeDelta();
    error Mirror__PuppetListEmpty();
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
    error Mirror__KeeperFeeExceedsAdjustmentRatio(uint keeperFee, uint allocationAmount);
    error Mirror__PuppetListMismatch(uint expected, uint provided);
    error Mirror__KeeperFeeNotFullyCovered(uint totalPaid, uint requiredFee);

    error Settle__InvalidAllocation(address allocationAddress);
    error Settle__InvalidKeeperExecutionFeeAmount();
    error Settle__InvalidKeeperExecutionFeeReceiver();
    error Settle__KeeperFeeExceedsSettledAmount(uint keeperFee, uint settledAmount);
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
    error Account__InsufficientBalance();

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
