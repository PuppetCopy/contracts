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

    error TokenRouter__InvalidTransferGasLimit();

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

    // Allocate errors
    error Allocate__InsufficientBalance();
    error Allocate__ActiveShares(uint totalShares);
    error Allocate__AlreadyRegistered();
    error Allocate__UnregisteredMaster();
    error Allocate__TransferFailed();
    error Allocate__ArrayLengthMismatch(uint puppetCount, uint allocationCount);
    error Allocate__PuppetListTooLarge(uint provided, uint maximum);
    error Allocate__IntentExpired(uint deadline, uint currentTime);
    error Allocate__InvalidSignature(address signer);
    error Allocate__InvalidMasterOwner(address expected, address provided);
    error Allocate__UnauthorizedSigner(address signer);
    error Allocate__InvalidNonce(uint expected, uint provided);
    error Allocate__InvalidPosition();
    error Allocate__InvalidMasterHook();
    error Allocate__InvalidTokenRouter();
    error Allocate__InvalidMaxPuppetList();
    error Allocate__InvalidGasLimit();
    error Allocate__TokenNotAllowed();
    error Allocate__DepositExceedsCap(uint amount, uint cap);
    error Allocate__MasterFrozen();
    error Allocate__ZeroAmount();
    error Allocate__ZeroShares();
    error Allocate__InsufficientLiquidity();
    error Allocate__AmountMismatch(uint expected, uint actual);
    error Allocate__InvalidAccountCodeHash();
    error Allocate__ExecutorNotInstalled();
    error Allocate__MasterHookNotInstalled();
    error Allocate__InvalidCompact();
    error Allocate__NetValueBelowMin(uint256 netValue, uint256 acceptableNetValue);
    error Allocate__NetValueAboveMax(uint256 netValue, uint256 acceptableNetValue);
    error Allocate__NetValueParamsMismatch();
    error Allocate__TokenMismatch();
    error Allocate__ZeroAssets();
    error Allocate__MasterDisposed();
    error Allocate__UninstallDisabled();
    error Allocate__InvalidAttestation();
    error Allocate__AttestationExpired(uint deadline, uint currentTime);
    error Allocate__InvalidAttestor();

    // Attest errors
    error Attest__InvalidAttestor();
    error Attest__InvalidSignature();

    // Compact errors
    error Compact__InvalidAttestor();
    error Compact__InvalidSignature();
    error Compact__ExpiredDeadline();
    error Compact__ArrayLengthMismatch();

    // NonceLib errors
    error NonceLib__InvalidNonce(uint nonce);
    error NonceLib__InvalidNonceForAccount(address account, uint nonce);

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

    error UserRouter__UnauthorizedCaller();

    // Match errors
    error Match__TransferMismatch();
    error Match__InvalidConfig();
    error Match__InvalidMinThrottlePeriod();
    error Match__ThrottlePeriodBelowMin(uint provided, uint minimum);

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
