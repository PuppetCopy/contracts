// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {Error} from "../shared/Error.sol";
import {CoreContract} from "../utils/CoreContract.sol";
import {EventEmitter} from "../utils/EventEmitter.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {MirrorPositionStore} from "./store/MirrorPositionStore.sol";
import {GmxPositionUtils} from "./utils/GmxPositionUtils.sol";

contract ExecuteIncreasePositionLogic is CoreContract {
    MirrorPositionStore positionStore;

    constructor(
        IAuthority _authority,
        EventEmitter _eventEmitter,
        MirrorPositionStore _positionStore
    ) CoreContract("ExecuteIncreasePositionLogic", "1", _authority, _eventEmitter) {
        positionStore = _positionStore;
    }

    function execute(bytes32 requestKey, GmxPositionUtils.Props memory /*order*/ ) external auth {
        MirrorPositionStore.RequestAdjustment memory request = positionStore.getRequestAdjustment(requestKey);

        if (request.positionKey == bytes32(0)) {
            revert Error.ExecuteIncreasePositionLogic__RequestDoesNotExist();
        }

        MirrorPositionStore.Position memory mirrorPosition = positionStore.getPosition(request.positionKey);

        mirrorPosition.traderSize += request.traderSizeDelta;
        mirrorPosition.traderCollateral += request.traderCollateralDelta;
        mirrorPosition.puppetSize += request.puppetSizeDelta;
        mirrorPosition.puppetCollateral += request.puppetCollateralDelta;
        mirrorPosition.cumulativeTransactionCost += request.transactionCost;

        positionStore.removeRequestAdjustment(requestKey);
        positionStore.setPosition(requestKey, mirrorPosition);

        logEvent(
            "execute",
            abi.encode(
                requestKey,
                request.positionKey,
                mirrorPosition.traderSize,
                mirrorPosition.traderCollateral,
                mirrorPosition.puppetSize,
                mirrorPosition.puppetCollateral,
                mirrorPosition.cumulativeTransactionCost
            )
        );
    }
}
