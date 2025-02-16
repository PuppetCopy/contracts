// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {GmxPositionUtils} from "../position/utils/GmxPositionUtils.sol";

library Error {
    // ExternalCallUtils
    error ExternalCallUtils__EmptyReceiver();
    error ExternalCallUtils__AddressEmptyCode(address target);
    error ExternalCallUtils__FailedInnerCall();
    error ExternalCallUtils__SafeERC20FailedOperation(address token);

    // TransferUtils
    error TransferUtils__EmptyTokenTranferGasLimit(IERC20 token);
    error TransferUtils__TokenTransferError(IERC20 token, address receiver, uint amount);
    error TransferUtils__EmptyHoldingAddress();

    event TransferUtils__TokenTransferReverted(string reason, bytes returndata);

    // Dictator
    error Dictator__ConfigurationUpdateFailed();
    error Dictator__ContractNotInitialized();
    error Dictator__ContractAlreadyInitialized();

    // VotingEscrow
    error VotingEscrow__Unsupported();

    // Core
    error CoreContract__Unauthorized(string contractName, string version);

    // RewardDistributor
    error RewardDistributor__InvalidAmount();
    error RewardDistributor__InsufficientRewards(uint accured);

    // VotingEscrowLogic
    error VotingEscrowLogic__ZeroAmount();
    error VotingEscrowLogic__ExceedMaxTime();
    error VotingEscrowLogic__ExceedingAccruedAmount(uint accured);

    // Access Control
    error Access__Unauthorized();
    error Permission__Unauthorized(address user);

    // Stores
    error Store__InvalidLength();

    // PuppetStore
    error PuppetStore__OverwriteAllocation();

    // RulebookLogic
    error RulebookLogic__InvalidAllowanceRate(uint min, uint max);
    error RulebookLogic__TokenNotAllowed();
    error RulebookLogic__AllowanceAboveLimit(uint allowanceCap);
    error RulebookLogic__InvalidAmount();
    error RulebookLogic__InsufficientBalance();
    error RulebookLogic__InvalidLength();
    error RulebookLogic__InvalidActivityThrottle(uint minAllocationActivity, uint maxAllocationActivity);

    // RequestLogic
    error RequestLogic__ValueNotFound();
    error RequestLogic__NoAllocation();
    error RequestLogic__PendingExecution();
    error RequestLogic__InvalidAllocationMatchKey();

    // AllocationLogic
    error AllocationLogic__AllocationAlreadyExists();
    error AllocationLogic__PendingSettlement();
    error AllocationLogic__PuppetListLimit();
    error AllocationLogic__InvalidPuppetListIntegrity();
    error AllocationLogic__InvalidListLength();
    error AllocationLogic__AllocationDoesNotExist();

    // ExecutionLogic
    error ExecutionLogic__RequestDoesNotExist();
    error ExecutionLogic__InvalidRequest(bytes32 positionKey, bytes32 key);
    error ExecutionLogic__UnexpectedEventData();
    error ExecutionLogic__MismatchedAmountIn(uint recordedAmountIn, uint amountIn);
    error ExecutionLogic__PositionDoesNotExist();
    error ExecutionLogic__RequestDoesNotMatchExecution();
    error ExecutionLogic__AllocationDoesNotExist();

    // PositionRouter
    error PositionRouter__InvalidOrderType(GmxPositionUtils.OrderType orderType);

    // Subaccount
    error Subaccount__UnauthorizedOperator();

    // FeeMarketplace
    error FeeMarketplace__NotAuctionableToken();
    error FeeMarketplace__InsufficientUnlockedBalance(uint accruedReward);
    error FeeMarketplace__ZeroDeposit();

    // PuppetToken
    error PuppetToken__InvalidRate();
    error PuppetToken__ExceededRateLimit(uint rateLimit, uint emissionRate);
    error PuppetToken__CoreShareExceedsMining();
}
