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
    error Allocation__InsufficientBalance();
    error Allocation__ActiveShares(uint totalShares);
    error Allocation__AlreadyRegistered();
    error Allocation__UnregisteredSubaccount();
    error Allocation__TransferFailed();
    error Allocation__ArrayLengthMismatch(uint puppetCount, uint allocationCount);
    error Allocation__PuppetListTooLarge(uint provided, uint maximum);
    error Allocation__IntentExpired(uint deadline, uint currentTime);
    error Allocation__InvalidSignature(address expected, address recovered);
    error Allocation__InvalidNonce(uint expected, uint provided);
    error Allocation__InvalidPosition();
    error Allocation__InvalidMasterHook();
    error Allocation__InvalidMaxPuppetList();
    error Allocation__InvalidGasLimit();
    error Allocation__TokenNotAllowed();
    error Allocation__DepositExceedsCap(uint amount, uint cap);
    error Allocation__SubaccountFrozen();
    error Allocation__ZeroAmount();
    error Allocation__ZeroShares();
    error Allocation__InsufficientLiquidity();
    error Allocation__AmountMismatch(uint expected, uint actual);
    error Allocation__InvalidAccountCodeHash();
    error Allocation__MasterHookNotInstalled();
    error Allocation__NetValueBelowMin(uint256 netValue, uint256 acceptableNetValue);
    error Allocation__NetValueAboveMax(uint256 netValue, uint256 acceptableNetValue);
    error Allocation__NetValueParamsMismatch();
    error Allocation__TokenMismatch();
    error Allocation__ZeroAssets();
    error Allocation__DisposedWithShares();

    error FeeMarketplace__InsufficientUnlockedBalance(uint unlockedBalance);
    error FeeMarketplace__ZeroDeposit();
    error FeeMarketplace__InvalidConfig();

    // Position errors
    error Position__UnknownStage(bytes32 stage);
    error Position__InvalidAction(bytes32 action);
    error Position__DelegateCallBlocked();
    error Position__InvalidBalanceChange();
    error Position__PendingOrdersExist();
    error Position__NotPositionOwner();
    error Position__OrderStillPending();
    error Position__InvalidStage();
    error Position__ArrayLengthMismatch();
    error Position__BatchOrderNotAllowed();

    // GmxStage errors
    error GmxStage__InvalidCallData();
    error GmxStage__InvalidCallType();
    error GmxStage__InvalidTarget();
    error GmxStage__InvalidOrderType();
    error GmxStage__InvalidReceiver();
    error GmxStage__InvalidAction();
    error GmxStage__InvalidBalanceChange();
    error GmxStage__InvalidExecutionSequence();
    error GmxStage__MissingPriceFeed(address token);
    error GmxStage__InvalidPrice(address token);
}
