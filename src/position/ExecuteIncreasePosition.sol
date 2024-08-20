// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {Permission} from "../utils/access/Permission.sol";

import {GmxPositionUtils} from "./utils/GmxPositionUtils.sol";
import {PositionStore} from "./store/PositionStore.sol";

contract ExecuteIncreasePosition is Permission, EIP712 {
    event ExecuteIncreasePosition__SetConfig(uint timestamp, CallConfig callConfig);
    event ExecuteIncreasePosition__Execute(bytes32 requestKey);

    struct CallConfig {
        PositionStore positionStore;
    }

    CallConfig callConfig;

    constructor(IAuthority _authority, CallConfig memory _callConfig) Permission(_authority) EIP712("ExecuteIncreasePosition", "1") {
        _setConfig(_callConfig);
    }

    function execute(bytes32 requestKey, GmxPositionUtils.Props memory order) external auth {
        PositionStore.RequestAdjustment memory request = callConfig.positionStore.getRequestAdjustment(requestKey);
        PositionStore.MirrorPosition memory mirrorPosition = callConfig.positionStore.getMirrorPosition(request.positionKey);

        if (mirrorPosition.size == 0) {
            PositionStore.RequestMatch memory matchRequest = callConfig.positionStore.getRequestMatch(request.positionKey);
            mirrorPosition.trader = matchRequest.trader;
            mirrorPosition.puppetList = matchRequest.puppetList;
            mirrorPosition.collateralList = request.collateralDeltaList;

            callConfig.positionStore.removeRequestMatch(request.positionKey);
        } else {
            // fill mirror position collateralList list
            for (uint i = 0; i < mirrorPosition.puppetList.length; i++) {
                mirrorPosition.collateralList[i] += request.collateralDeltaList[i];
            }
        }

        mirrorPosition.collateral += request.collateralDelta;
        mirrorPosition.size += request.sizeDelta;
        mirrorPosition.cumulativeTransactionCost += request.transactionCost;

        callConfig.positionStore.setMirrorPosition(requestKey, mirrorPosition);
        callConfig.positionStore.removeRequestAdjustment(requestKey);

        emit ExecuteIncreasePosition__Execute(requestKey);
    }

    // governance

    function setConfig(CallConfig memory _callConfig) external auth {
        _setConfig(_callConfig);
    }

    function _setConfig(CallConfig memory _callConfig) internal {
        callConfig = _callConfig;

        emit ExecuteIncreasePosition__SetConfig(block.timestamp, callConfig);
    }

    error ExecuteIncreasePosition__UnauthorizedCaller();
}
