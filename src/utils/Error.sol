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

    error Access__CallerNotAuthority();
    error Access__Unauthorized();

    error Permission__Unauthorized();
    error Permission__CallerNotAuthority();

    error Allocate__AlreadyRegistered();
    error Allocate__UnregisteredMaster();
    error Allocate__ArrayLengthMismatch(uint puppetCount, uint allocationCount);
    error Allocate__TokenNotAllowed();
    error Allocate__DepositExceedsCap(uint amount, uint cap);
    error Allocate__ZeroAmount();
    error Allocate__AmountMismatch(uint expected, uint actual);
    error Allocate__InvalidAccountCodeHash();
    error Allocate__UninstallDisabled();
    error Allocate__InvalidAttestation();
    error Allocate__AttestationExpired(uint deadline, uint currentTime);
    error Allocate__AttestationBlockStale(uint attestedBlock, uint currentBlock, uint maxStaleness);
    error Allocate__AttestationTimestampStale(uint attestedTimestamp, uint currentTimestamp, uint maxAge);
    error Allocate__InvalidAttestor();
    error Allocate__InvalidMaster();

    error MasterHook__UninstallDisabled();

    error Registry__InvalidAccountCodeHash();
    error Registry__AlreadyRegistered();
    error Registry__TokenNotAllowed();

    error Compact__ArrayLengthMismatch();

    error NonceLib__InvalidNonce(uint nonce);
    error NonceLib__InvalidNonceForAccount(address account, uint nonce);

    error FeeMarketplace__InsufficientUnlockedBalance(uint unlockedBalance);
    error FeeMarketplace__ZeroDeposit();
    error FeeMarketplace__InvalidConfig();

    error Position__DelegateCallBlocked();
    error Position__PendingOrdersExist();
    error Position__NotPositionOwner();
    error Position__OrderStillPending();
    error Position__InvalidStage();
    error Position__InvalidAction();
    error Position__InvalidBaseToken();
    error Position__ArrayLengthMismatch();
    error Position__BatchOrderNotAllowed();

    error UserRouter__UnauthorizedCaller();

    error Match__InvalidMinThrottlePeriod();
    error Match__ThrottlePeriodBelowMin(uint provided, uint minimum);

    error GmxStage__InvalidCallData();
    error GmxStage__InvalidCallType();
    error GmxStage__InvalidTarget();
    error GmxStage__InvalidOrderType();
    error GmxStage__InvalidReceiver();
    error GmxStage__InvalidAction();
    error GmxStage__InvalidExecutionSequence();
    error GmxStage__MissingPriceFeed(address token);
    error GmxStage__InvalidPrice(address token);

    error Withdraw__ExpiredDeadline();
    error Withdraw__ZeroShares();
    error Withdraw__InvalidUser();
    error Withdraw__InvalidMaster();
    error Withdraw__InvalidToken();
    error Withdraw__SharesMismatch();
    error Withdraw__NonceMismatch();
    error Withdraw__SharePriceBelowMin();
    error Withdraw__AmountBelowMin();
    error Withdraw__InvalidUserSignature();
    error Withdraw__InvalidAttestorSignature();
    error Withdraw__TransferAmountMismatch();
    error Withdraw__UninstallDisabled();
    error Withdraw__InvalidConfig();
    error Withdraw__AttestationBlockStale(uint attestedBlock, uint currentBlock, uint maxStaleness);
    error Withdraw__AttestationTimestampStale(uint attestedTimestamp, uint currentTimestamp, uint maxAge);
}
