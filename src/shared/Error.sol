// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

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

    error RequestPositionLogic__ValueNotFound();
    error RequestPositionLogic__NoAllocation();
    error RequestPositionLogic__PendingExecution();
    error RequestPositionLogic__InvalidAllocationMatchKey();

    error AllocationLogic__AllocationStillUtilized();
    error AllocationLogic__PuppetListLimit();
    error AllocationLogic__InvalidPuppetListIntegrity();
    error AllocationLogic__InvalidListLength();
    error AllocationLogic__AllocationDoesNotExist();

    error ExecuteIncreasePositionLogic__RequestDoesNotExist();

    error ExecuteDecreasePositionLogic__InvalidRequest(bytes32 positionKey, bytes32 key);
    error ExecuteDecreasePositionLogic__UnexpectedEventData();
    error ExecuteDecreasePositionLogic__MismatchedAmountIn(uint recordedAmountIn, uint amountIn);
    error ExecuteDecreasePositionLogic__RequestDoesNotExist();
    error ExecuteDecreasePositionLogic__PositionDoesNotExist();
    error ExecuteDecreasePositionLogic__AllocationDoesNotExist();

    error PositionRouter__InvalidOrderType(GmxPositionUtils.OrderType orderType);
}
