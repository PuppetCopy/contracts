// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {CoreContract} from "../utils/CoreContract.sol";
import {EventEmitter} from "../utils/EventEmitter.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {GmxPositionUtils} from "./utils/GmxPositionUtils.sol";

import {PositionStore} from "./store/PositionStore.sol";

contract ExecuteIncreasePositionLogic is CoreContract {
    struct Config {
        uint __;
    }

    PositionStore positionStore;
    Config config;

    constructor(
        IAuthority _authority,
        EventEmitter _eventEmitter,
        PositionStore _positionStore,
        Config memory _config
    ) CoreContract("ExecuteIncreasePositionLogic", "1", _authority, _eventEmitter) {
        positionStore = _positionStore;
        _setConfig(_config);
    }

    function execute(bytes32 requestKey, GmxPositionUtils.Props memory order) external auth {
        PositionStore.RequestAdjustment memory request = positionStore.getRequestAdjustment(requestKey);
        PositionStore.MirrorPosition memory mirrorPosition = positionStore.getMirrorPosition(request.positionKey);

        mirrorPosition.traderSize += request.traderSizeDelta;
        mirrorPosition.traderCollateral += request.traderCollateralDelta;
        mirrorPosition.puppetSize += request.puppetSizeDelta;
        mirrorPosition.puppetCollateral += request.puppetCollateralDelta;
        mirrorPosition.cumulativeTransactionCost += request.transactionCost;

        positionStore.removeRequestAdjustment(requestKey);
        positionStore.setMirrorPosition(requestKey, mirrorPosition);

        logEvent("execute", abi.encode(requestKey, mirrorPosition));
    }

    // governance

    /// @notice Set the mint rate limit for the token.
    /// @param _config The new rate limit configuration.
    function setConfig(Config calldata _config) external auth {
        _setConfig(_config);
    }

    /// @dev Internal function to set the configuration.
    /// @param _config The configuration to set.
    function _setConfig(Config memory _config) internal {
        config = _config;
        logEvent("setConfig", abi.encode(_config));
    }

    error ExecuteIncreasePositionLogic__UnauthorizedCaller();
}
