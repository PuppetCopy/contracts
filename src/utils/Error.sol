// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

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
    error Dictatorship__InvalidCoreContract();

    error BankStore__InsufficientBalance();

    error PuppetVoteToken__Unsupported();


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

    error Allocation__InsufficientMasterBalance(uint available, uint required);
    error Allocation__InsufficientAllocation(uint available, uint required);
    error Allocation__PuppetListTooLarge(uint provided, uint maximum);
    error Allocation__ZeroAllocation();
    error Allocation__NoUtilization();
    error Allocation__UtilizationNotSettled(uint utilization);
    error Allocation__UnregisteredSubaccount();
    error Allocation__ExecutorNotInstalled();
    error Allocation__ActiveUtilization(uint totalUtilization);
    error Allocation__AlreadyRegistered();
    error Allocation__AlreadyUnregistered();
    error Allocation__TransferFailed();
    error Allocation__InsufficientMasterAllocation(uint available, uint required);
    error Allocation__UtilizationExceedsAllocation(uint utilized, uint allocated);
    error Allocation__ArrayLengthMismatch(uint puppetCount, uint allocationCount);
    error Allocation__TargetNotWhitelisted(address target);
    error Allocation__DelegateCallNotAllowed();
    error Allocation__InvalidCallType();

    error FeeMarketplace__InsufficientUnlockedBalance(uint unlockedBalance);
    error FeeMarketplace__ZeroDeposit();
    error FeeMarketplace__InvalidConfig();

    error VenueRegistry__ContractNotWhitelisted(address venue);
}
