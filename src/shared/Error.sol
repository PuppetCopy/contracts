// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {GmxPositionUtils} from "../position/utils/GmxPositionUtils.sol";

library Error {
    error Dictator__ConfigurationUpdateFailed();
    error Dictator__ContractNotInitialized();
    error Dictator__ContractAlreadyInitialized();
    error CoreContract__Unauthorized(string contractName, string version);

    error Access__Unauthorized();
    error Permission__Unauthorized(address user);

    error Store__InvalidLength();

    error PuppetStore__OverwriteAllocation();

    error PuppetLogic__InvalidAllowanceRate(uint min, uint max);
    error PuppetLogic__TokenNotAllowed();
    error PuppetLogic__AllowanceAboveLimit(uint allowanceCap);
    error PuppetLogic__InvalidAmount();
    error PuppetLogic__InsufficientBalance();
    error PuppetLogic__InvalidLength();
    error PuppetLogic__InvalidActivityThrottle(uint minAllocationActivity, uint maxAllocationActivity);

    error RequestLogic__ValueNotFound();
    error RequestLogic__NoAllocation();
    error RequestLogic__PendingExecution();
    error RequestLogic__InvalidAllocationMatchKey();

    error AllocationLogic__UtillizedAllocationed();
    error AllocationLogic__PendingSettlment();
    error AllocationLogic__PuppetListLimit();
    error AllocationLogic__InvalidPuppetListIntegrity();
    error AllocationLogic__InvalidListLength();
    error AllocationLogic__AllocationDoesNotExist();

    error ExecutionLogic__RequestDoesNotExist();
    error ExecutionLogic__InvalidRequest(bytes32 positionKey, bytes32 key);
    error ExecutionLogic__UnexpectedEventData();
    error ExecutionLogic__MismatchedAmountIn(uint recordedAmountIn, uint amountIn);
    error ExecutionLogic__PositionDoesNotExist();
    error ExecutionLogic__RequestDoesNotMatchExecution();
    error ExecutionLogic__AllocationDoesNotExist();

    error PositionRouter__InvalidOrderType(GmxPositionUtils.OrderType orderType);

    error Subaccount__UnauthorizedOperator();

    /// @notice Error emitted when the claim token is invalid
    error FeeMarketplace__NotAuctionableToken();

    /// @notice Error emitted when the claimable reward is insufficient
    error FeeMarketplace__InsufficientUnlockedBalance(uint accruedReward);

    /// @dev Error for when the rate is invalid (zero).
    error PuppetToken__InvalidRate();
    /// @dev Error for when the minting exceeds the rate limit.
    /// @param rateLimit The rate limit.
    /// @param emissionRate The current emission rate.
    error PuppetToken__ExceededRateLimit(uint rateLimit, uint emissionRate);
    /// @dev Error for when the core share exceeds the mintable amount.
    error PuppetToken__CoreShareExceedsMining();

    /// @notice Error emitted when there is no claimable amount for a user
    error RewardLogic__InvalidAmount();
    error RewardLogic__InsufficientRewards(uint accruedReward);

    /// @notice Transfers are restricted in this contract.
    error VotingEscrow__Unsupported();

    error VotingEscrowLogic__ZeroAmount();
    error VotingEscrowLogic__ExceedMaxTime();
    error VotingEscrowLogic__ExceedingAccruedAmount(uint accrued);

    error ExternalCallUtils__EmptyReceiver();
    error ExternalCallUtils__AddressEmptyCode(address target);
    error ExternalCallUtils__FailedInnerCall();
    error ExternalCallUtils__SafeERC20FailedOperation(address token);

    error TransferUtils__EmptyTokenTranferGasLimit(address token);
    error TransferUtils__TokenTransferError(address token, address receiver, uint amount);
    error TransferUtils__EmptyHoldingAddress();

    event TransferUtils__TokenTransferReverted(string reason, bytes returndata);
}
