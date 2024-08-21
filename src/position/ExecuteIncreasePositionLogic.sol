// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {CoreContract} from "../utils/CoreContract.sol";
import {EventEmitter} from "../utils/EventEmitter.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {GmxPositionUtils} from "./utils/GmxPositionUtils.sol";

import {PositionStore} from "./store/PositionStore.sol";

contract ExecuteIncreasePositionLogic is CoreContract {
    event ExecuteIncreasePositionLogic__SetConfig(uint timestamp, Config config);

    struct Config {
        PositionStore positionStore;
    }

    Config config;

    constructor(
        IAuthority _authority,
        EventEmitter _eventEmitter,
        Config memory _config
    ) CoreContract("ExecuteIncreasePositionLogic", "1", _authority, _eventEmitter) {
        _setConfig(_config);
    }

    function execute(bytes32 requestKey, GmxPositionUtils.Props memory order) external auth {
        PositionStore.RequestAdjustment memory request = config.positionStore.getRequestAdjustment(requestKey);
        PositionStore.MirrorPosition memory mirrorPosition = config.positionStore.getMirrorPosition(request.positionKey);

        if (mirrorPosition.size == 0) {
            PositionStore.RequestMatch memory matchRequest = config.positionStore.getRequestMatch(request.positionKey);
            mirrorPosition.trader = matchRequest.trader;
            mirrorPosition.puppetList = matchRequest.puppetList;
            mirrorPosition.collateralList = request.collateralDeltaList;

            config.positionStore.removeRequestMatch(request.positionKey);
        } else {
            // fill mirror position collateralList list
            for (uint i = 0; i < mirrorPosition.puppetList.length; i++) {
                mirrorPosition.collateralList[i] += request.collateralDeltaList[i];
            }
        }

        mirrorPosition.collateral += request.collateralDelta;
        mirrorPosition.size += request.sizeDelta;
        mirrorPosition.cumulativeTransactionCost += request.transactionCost;

        config.positionStore.setMirrorPosition(requestKey, mirrorPosition);
        config.positionStore.removeRequestAdjustment(requestKey);

        eventEmitter.log("ExecuteIncreasePositionLogic", abi.encode(requestKey, request.positionKey));
    }

    // governance

    function setConfig(Config memory _config) external auth {
        _setConfig(_config);
    }

    function _setConfig(Config memory _config) internal {
        config = _config;

        emit ExecuteIncreasePositionLogic__SetConfig(block.timestamp, _config);
    }

    error ExecuteIncreasePositionLogic__UnauthorizedCaller();
}
