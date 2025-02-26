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

    // MatchRule
    error MatchRule__InvalidAllowanceRate(uint min, uint max);
    error MatchRule__TokenNotAllowed();
    error MatchRule__AllowanceAboveLimit(uint allowanceCap);
    error MatchRule__InvalidAmount();
    error MatchRule__InsufficientBalance();
    error MatchRule__InvalidLength();
    error MatchRule__InvalidActivityThrottle(uint minAllocationActivity, uint maxAllocationActivity);

    // MirrorPosition
    error MirrorPosition__AllocationAlreadyExists();
    error MirrorPosition__PendingSettlement();
    error MirrorPosition__PuppetListLimit();
    error MirrorPosition__InvalidPuppetListIntegrity();
    error MirrorPosition__InvalidListLength();
    error MirrorPosition__AllocationDoesNotExist();
    error MirrorPosition__RequestDoesNotExist();
    error MirrorPosition__InvalidRequest(bytes32 positionKey, bytes32 key);
    error MirrorPosition__UnexpectedEventData();
    error MirrorPosition__MismatchedAmountIn(uint recordedAmountIn, uint amountIn);
    error MirrorPosition__PositionDoesNotExist();
    error MirrorPosition__RequestDoesNotMatchExecution();
    error MirrorPosition__NoAllocation();
    error MirrorPosition__PendingExecution();

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
