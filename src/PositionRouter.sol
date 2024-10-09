// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {AllocationLogic} from "./position/AllocationLogic.sol";
import {ExecutionLogic} from "./position/ExecutionLogic.sol";
import {RequestLogic} from "./position/RequestLogic.sol";
import {UnhandledCallbackLogic} from "./position/UnhandledCallbackLogic.sol";
import {IGmxOrderCallbackReceiver} from "./position/interface/IGmxOrderCallbackReceiver.sol";
import {MirrorPositionStore} from "./position/store/MirrorPositionStore.sol";
import {GmxPositionUtils} from "./position/utils/GmxPositionUtils.sol";
import {Error} from "./shared/Error.sol";
import {CoreContract} from "./utils/CoreContract.sol";
import {EventEmitter} from "./utils/EventEmitter.sol";
import {ReentrancyGuardTransient} from "./utils/ReentrancyGuardTransient.sol";
import {IAuthority} from "./utils/interfaces/IAuthority.sol";

contract PositionRouter is CoreContract, ReentrancyGuardTransient, IGmxOrderCallbackReceiver {
    struct Config {
        RequestLogic requestLogic;
        AllocationLogic allocationLogic;
        ExecutionLogic executionLogic;
        UnhandledCallbackLogic unhandledCallbackLogic;
    }

    MirrorPositionStore immutable positionStore;

    Config public config;

    constructor(
        IAuthority _authority,
        EventEmitter _eventEmitter,
        MirrorPositionStore _positionStore
    ) CoreContract("PositionRouter", "1", _authority, _eventEmitter) {
        positionStore = _positionStore;
    }

    function afterOrderExecution(
        bytes32 key,
        GmxPositionUtils.Props calldata order,
        bytes calldata eventData
    ) external nonReentrant auth {
        try config.executionLogic.handleExecution(key, order, eventData) {}
        catch {
            config.unhandledCallbackLogic.storeUnhandledCallback(order, key, eventData);
        }
    }

    function afterOrderCancellation(
        bytes32 key, //
        GmxPositionUtils.Props calldata order,
        bytes calldata eventData
    ) external nonReentrant auth {
        try config.executionLogic.handleCancelled(key, order, eventData) {}
        catch {
            config.unhandledCallbackLogic.storeUnhandledCallback(order, key, eventData);
        }
    }

    function afterOrderFrozen(
        bytes32 key,
        GmxPositionUtils.Props calldata order,
        bytes calldata eventData
    ) external nonReentrant auth {
        try config.executionLogic.handleFrozen(key, order, eventData) {}
        catch {
            config.unhandledCallbackLogic.storeUnhandledCallback(order, key, eventData);
        }
    }

    function allocate(
        IERC20 collateralToken,
        bytes32 originRequestKey,
        bytes32 matchKey,
        address[] calldata puppetList
    ) external nonReentrant auth returns (bytes32 allocationKey) {
        return config.allocationLogic.allocate(collateralToken, originRequestKey, matchKey, puppetList);
    }

    function mirror(
        RequestLogic.MirrorPositionParams calldata params
    ) external payable nonReentrant auth {
        config.requestLogic.mirror(params);
    }

    function settle(bytes32 key, address[] calldata puppetList) external nonReentrant auth {
        config.allocationLogic.settle(key, puppetList);
    }

    // governance

    /// @notice Set the mint rate limit for the token.
    /// @param _config The new rate limit configuration.
    function setConfig(
        Config calldata _config
    ) external auth {
        config = _config;
        logEvent("SetConfig", abi.encode(_config));
    }
}
