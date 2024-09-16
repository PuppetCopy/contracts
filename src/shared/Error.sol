// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {GmxPositionUtils} from "../position/utils/GmxPositionUtils.sol";

library Error {
    error PuppetStore__InvalidLength();

    error PuppetLogic__InvalidAllowanceRate(uint min, uint max);
    error PuppetLogic__ExpiredDate();
    error PuppetLogic__NotFound();
    error PuppetLogic__TokenNotAllowed();
    error PuppetLogic__AllowanceAboveLimit(uint allowanceCap);
    error PuppetLogic__InvalidAmount();
    error PuppetLogic__InsufficientBalance();
    error PuppetLogic__InvalidLength();

    error RequestPositionLogic__PuppetListLimitExceeded();
    error RequestPositionLogic__ExistingRequestPending();
    error RequestPositionLogic__UnsortedPuppetList();
    error RequestPositionLogic__DuplicatesInPuppetList();

    error ExecuteIncreasePositionLogic__RequestDoesNotExist();

    error ExecuteDecreasePositionLogic__RequestDoesNotExist();
    error ExecuteDecreasePositionLogic__InvalidRequest(bytes32 positionKey, bytes32 key);
    error ExecuteDecreasePositionLogic__UnexpectedEventData();
    error ExecuteDecreasePositionLogic__MismatchedRecordedAmountIn(uint recordedAmountIn, uint totalAmountIn);

    error PositionRouter__InvalidOrderType(GmxPositionUtils.OrderType orderType);


}
