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

    // Allocation errors
    error Allocation__InsufficientBalance(uint available, uint required);
    error Allocation__ActiveShares(uint totalShares);
    error Allocation__AlreadyRegistered();
    error Allocation__UnregisteredSubaccount();
    error Allocation__TransferFailed();
    error Allocation__NetValueBelowAcceptable(uint netValue, uint acceptable);
    error Allocation__ArrayLengthMismatch(uint puppetCount, uint allocationCount);
    error Allocation__PuppetListTooLarge(uint provided, uint maximum);
    error Allocation__TargetNotWhitelisted(address target);
    error Allocation__InvalidCallType();
    error Allocation__IntentExpired(uint deadline, uint currentTime);
    error Allocation__InvalidSignature(address expected, address recovered);
    error Allocation__InvalidNonce(uint expected, uint provided);
    error Allocation__InvalidMaxPuppetList();
    error Allocation__InvalidTransferGasLimit();
    error Allocation__InvalidCallGasLimit();

    error FeeMarketplace__InsufficientUnlockedBalance(uint unlockedBalance);
    error FeeMarketplace__ZeroDeposit();
    error FeeMarketplace__InvalidConfig();

    error VenueRegistry__ContractNotWhitelisted(address venue);

    error Position__VenueNotRegistered(bytes32 venueKey);

    error GmxVenueValidator__InvalidCallData();
    error GmxVenueValidator__TokenMismatch(address expected, address actual);
    error GmxVenueValidator__AmountMismatch(uint expected, uint actual);

}
