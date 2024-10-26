// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {AllocationLogic} from "./position/AllocationLogic.sol";
import {ExecutionLogic} from "./position/ExecutionLogic.sol";
import {RequestLogic} from "./position/RequestLogic.sol";
import {UnhandledCallbackLogic} from "./position/UnhandledCallbackLogic.sol";
import {IGmxOrderCallbackReceiver} from "./position/interface/IGmxOrderCallbackReceiver.sol";
import {PositionStore} from "./position/store/PositionStore.sol";
import {GmxPositionUtils} from "./position/utils/GmxPositionUtils.sol";
import {Error} from "./shared/Error.sol";
import {CoreContract} from "./utils/CoreContract.sol";
import {ReentrancyGuardTransient} from "./utils/ReentrancyGuardTransient.sol";
import {IAuthority} from "./utils/interfaces/IAuthority.sol";

contract PositionRouter is CoreContract, ReentrancyGuardTransient, IGmxOrderCallbackReceiver {
    struct Config {
        RequestLogic requestLogic;
        AllocationLogic allocationLogic;
        ExecutionLogic executionLogic;
        UnhandledCallbackLogic unhandledCallbackLogic;
    }

    PositionStore immutable positionStore;

    Config public config;

    constructor(
        IAuthority _authority,
        PositionStore _positionStore
    ) CoreContract("PositionRouter", "1", _authority) {
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
        bytes32 sourceRequestKey,
        bytes32 matchKey,
        address[] calldata puppetList
    ) external nonReentrant auth returns (bytes32 allocationKey) {
        return config.allocationLogic.allocate(collateralToken, sourceRequestKey, matchKey, puppetList);
    }

    function mirror(
        RequestLogic.MirrorPositionParams calldata params
    ) external payable nonReentrant auth {
        config.requestLogic.mirror(params);
    }

    function settle(bytes32 key, address[] calldata puppetList) external nonReentrant auth {
        config.allocationLogic.settle(key, puppetList);
    }

    function _setConfig(
        bytes calldata data
    ) internal override {
        config = abi.decode(data, (Config));
    }
}
