// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {PuppetStore} from "../puppet/store/PuppetStore.sol";
import {Error} from "../shared/Error.sol";
import {ContributeStore} from "../tokenomics/store/ContributeStore.sol";
import {CoreContract} from "../utils/CoreContract.sol";
import {EventEmitter} from "../utils/EventEmitter.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {Precision} from "./../utils/Precision.sol";
import {MirrorPositionStore} from "./store/MirrorPositionStore.sol";
import {GmxPositionUtils} from "./utils/GmxPositionUtils.sol";

contract ExecuteDecreasePositionLogic is CoreContract {
    MirrorPositionStore positionStore;
    PuppetStore puppetStore;

    constructor(
        IAuthority _authority,
        EventEmitter _eventEmitter,
        PuppetStore _puppetStore,
        MirrorPositionStore _positionStore
    ) CoreContract("ExecuteDecreasePositionLogic", "1", _authority, _eventEmitter) {
        puppetStore = _puppetStore;
        positionStore = _positionStore;
    }

    function execute(
        bytes32 requestKey,
        GmxPositionUtils.Props calldata, /*order*/
        bytes calldata /*eventData*/
    ) external auth {
        MirrorPositionStore.RequestAdjustment memory request = positionStore.getRequestAdjustment(requestKey);

        if (request.positionKey == bytes32(0)) {
            revert Error.ExecuteDecreasePositionLogic__RequestDoesNotExist();
        }

        MirrorPositionStore.Position memory position = positionStore.getPosition(request.positionKey);

        if (position.size == 0) {
            revert Error.ExecuteDecreasePositionLogic__PositionDoesNotExist();
        }

        PuppetStore.AllocationMatch memory allocation = puppetStore.getAllocationMatch(request.routeKey);

        uint recordedAmountIn = puppetStore.recordedTransferIn(position.collateralToken);
        uint adjustedAmountOut = allocation.amountOut * request.sizeDelta / position.size;
        uint profit = recordedAmountIn > adjustedAmountOut ? recordedAmountIn - adjustedAmountOut : 0;

        puppetStore.setSettlement(request.routeKey, recordedAmountIn, profit);

        position.size -= request.sizeDelta;
        position.cumulativeTransactionCost += request.transactionCost;

        // https://github.com/gmx-io/gmx-synthetics/blob/main/contracts/position/DecreasePositionUtils.sol#L91
        if (request.sizeDelta < position.size) {
            positionStore.setPosition(request.positionKey, position);
        } else {
            positionStore.removePosition(request.positionKey);
            puppetStore.removeAllocationMatch(request.positionKey);
        }

        positionStore.removeRequestDecrease(requestKey);

        logEvent("Execute", abi.encode(requestKey, request.positionKey, position.size, recordedAmountIn, profit));
    }
}
