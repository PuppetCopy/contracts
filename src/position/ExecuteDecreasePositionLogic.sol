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
    struct Config {
        uint _dummy;
    }

    PuppetStore immutable puppetStore;
    MirrorPositionStore immutable positionStore;

    Config public config;

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

        PuppetStore.Allocation memory allocation = puppetStore.getAllocation(request.matchKey);

        if (allocation.size == 0) {
            revert Error.ExecuteDecreasePositionLogic__PositionDoesNotExist();
        }

        allocation.settled += positionStore.recordTransferIn(allocation.collateralToken);

        // https://github.com/gmx-io/gmx-synthetics/blob/main/contracts/position/DecreasePositionUtils.sol#L91
        if (allocation.size > request.sizeDelta) {} else {
            allocation.size -= request.sizeDelta;
            // allocation.cumulativeTransactionCost += request.transactionCost;

            // positionStore.setPosition(request.positionKey, position);
        }

        puppetStore.setAllocation(request.matchKey, allocation);

        positionStore.removeRequestDecrease(requestKey);

        logEvent(
            "Execute",
            abi.encode(
                requestKey,
                request.traderRequestKey,
                request.traderPositionKey,
                request.matchKey,
                request.positionKey,
                request.sizeDelta,
                request.transactionCost,
                allocation.settled
            )
        );
    }

    // governance

    function setConfig(Config memory _config) external auth {
        config = _config;

        logEvent("SetConfig", abi.encode(_config));
    }
}
