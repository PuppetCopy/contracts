// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

// import {PuppetStore} from "../puppet/store/PuppetStore.sol";

import {PuppetStore} from "../puppet/store/PuppetStore.sol";
import {Error} from "../shared/Error.sol";
import {CoreContract} from "../utils/CoreContract.sol";
import {EventEmitter} from "../utils/EventEmitter.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {MirrorPositionStore} from "./store/MirrorPositionStore.sol";
import {GmxPositionUtils} from "./utils/GmxPositionUtils.sol";

contract ExecuteIncreasePositionLogic is CoreContract {
    MirrorPositionStore immutable positionStore;
    PuppetStore immutable puppetStore;

    constructor(
        IAuthority _authority,
        EventEmitter _eventEmitter,
        PuppetStore _puppetStore,
        MirrorPositionStore _positionStore
    ) CoreContract("ExecuteIncreasePositionLogic", "1", _authority, _eventEmitter) {
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
            revert Error.ExecuteIncreasePositionLogic__RequestDoesNotExist();
        }

        PuppetStore.Allocation memory allocation = puppetStore.getAllocation(request.matchKey);

        allocation.size += request.sizeDelta;
        positionStore.removeRequestAdjustment(requestKey);

        logEvent(
            "Execute",
            abi.encode(
                requestKey,
                request.traderPositionKey,
                request.matchKey,
                request.positionKey,
                request.sizeDelta,
                request.transactionCost
            )
        );
    }
}
