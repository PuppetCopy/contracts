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

    struct CallConfig {
        PositionStore positionStore;
    }

    CallConfig callConfig;

    constructor(IAuthority _authority, CallConfig memory _callConfig) Permission(_authority) EIP712("Position Router", "1") {
        _setConfig(_callConfig);
    }

    function increase(bytes32 key, GmxPositionUtils.Props memory order) external auth {
        bytes32 positionKey = GmxPositionUtils.getPositionKey(
            order.addresses.account, order.addresses.market, order.addresses.initialCollateralToken, order.flags.isLong
        );

        PositionStore.RequestAdjustment memory request = callConfig.positionStore.getRequestAdjustment(key);
        PositionStore.MirrorPosition memory mirrorPosition = callConfig.positionStore.getMirrorPosition(positionKey);

        if (mirrorPosition.size == 0) {
            PositionStore.RequestMatch memory matchRequest = callConfig.positionStore.getRequestMatch(positionKey);
            mirrorPosition.trader = matchRequest.trader;
            mirrorPosition.puppetList = matchRequest.puppetList;

            callConfig.positionStore.removeRequestMatch(positionKey);
        }

        mirrorPosition.collateral += request.collateralDelta;
        mirrorPosition.size += request.sizeDelta;
        mirrorPosition.cumulativeTransactionCost += request.transactionCost;

        callConfig.positionStore.setMirrorPosition(key, mirrorPosition);
        callConfig.positionStore.removeRequestAdjustment(key);
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
