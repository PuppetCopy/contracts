// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import {GmxPositionUtils} from "../position/utils/GmxPositionUtils.sol";

library Error {
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

    error AllocationLogic__AllocationStillUtilized();
    error AllocationLogic__PuppetListLimit();
    error AllocationLogic__InvalidPuppetListIntegrity();
    error AllocationLogic__InvalidListLength();
    error AllocationLogic__AllocationDoesNotExist();

    error ExecutionLogic__RequestDoesNotExist();
    error ExecutionLogic__InvalidRequest(bytes32 positionKey, bytes32 key);
    error ExecutionLogic__UnexpectedEventData();
    error ExecutionLogic__MismatchedAmountIn(uint recordedAmountIn, uint amountIn);
    error ExecutionLogic__PositionDoesNotExist();
    error ExecutionLogic__AllocationDoesNotExist();

    error PositionRouter__InvalidOrderType(GmxPositionUtils.OrderType orderType);
}
