// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

// import {PuppetStore} from "../puppet/store/PuppetStore.sol";
import {Error} from "../shared/Error.sol";
import {CoreContract} from "../utils/CoreContract.sol";
import {EventEmitter} from "../utils/EventEmitter.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {MirrorPositionStore} from "./store/MirrorPositionStore.sol";
import {GmxPositionUtils} from "./utils/GmxPositionUtils.sol";

contract ExecuteIncreasePositionLogic is CoreContract {
    MirrorPositionStore positionStore;
    // PuppetStore puppetStore;

    constructor(
        IAuthority _authority,
        EventEmitter _eventEmitter,
        // PuppetStore _puppetStore,
        MirrorPositionStore _positionStore
    ) CoreContract("ExecuteIncreasePositionLogic", "1", _authority, _eventEmitter) {
        // puppetStore = _puppetStore;
        positionStore = _positionStore;
    }

    function execute(
        bytes32 requestKey,
        GmxPositionUtils.Props calldata, /*order*/
        bytes calldata /*eventData*/
    ) external auth {
        MirrorPositionStore.RequestAdjustment memory request = positionStore.getRequestAdjustment(requestKey);

        if (request.positionKey == bytes32(0)) {
            revert Error.ExecuteIncreasePositionLogic__RequestDoesNotExist();
        }

        // PuppetStore.AllocationMatch memory allocation = puppetStore.getAllocationMatch(request.positionKey);

        MirrorPositionStore.Position memory position = positionStore.getPosition(request.positionKey);

        position.size += request.sizeDelta;
        position.cumulativeTransactionCost += request.transactionCost;

        positionStore.removeRequestAdjustment(requestKey);
        positionStore.setPosition(requestKey, position);

        logEvent(
            "Execute", abi.encode(requestKey, request.positionKey, position.size, position.cumulativeTransactionCost)
        );
    }
}
