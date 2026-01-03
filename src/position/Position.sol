// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC7579Account} from "modulekit/accounts/common/interfaces/IERC7579Account.sol";
import {ModeLib, ModeCode, CallType, CALLTYPE_SINGLE, CALLTYPE_BATCH, CALLTYPE_DELEGATECALL} from "modulekit/accounts/common/lib/ModeLib.sol";

import {CoreContract} from "../utils/CoreContract.sol";
import {Error} from "../utils/Error.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {IStage} from "./interface/IStage.sol";

/// @title Position
/// @notice Routes execute() calls to stage handlers for validation and tracks pending orders
contract Position is CoreContract {
    // ============ Constants ============

    uint8 public constant ACTION_NONE = 0;
    uint8 public constant ACTION_ORDER_CREATED = 1;

    // ============ State ============

    mapping(address target => IStage) public handlers;
    mapping(IStage stage => bool) public validStages;
    mapping(address subaccount => uint) public pendingOrderCount;

    // ============ Constructor ============

    constructor(IAuthority _authority) CoreContract(_authority, "") {}

    // ============ Views ============

    function processPreCall(address _master, address _subaccount, uint _msgValue, bytes calldata _msgData)
        external
        view
        returns (bytes memory hookData)
    {
        if (_msgData.length < 4) return "";
        if (bytes4(_msgData[:4]) != IERC7579Account.execute.selector) return "";

        ModeCode mode = ModeCode.wrap(bytes32(_msgData[4:36]));
        CallType callType = ModeLib.getCallType(mode);

        if (callType == CALLTYPE_DELEGATECALL) revert Error.Position__DelegateCallBlocked();
        if (callType != CALLTYPE_SINGLE && callType != CALLTYPE_BATCH) return "";

        bytes calldata execData = _msgData[36:];

        address firstTarget = address(bytes20(execData[:20]));
        IStage handler = handlers[firstTarget];
        if (address(handler) == address(0)) return "";

        (IERC20 token, bytes memory handlerData) = handler.validate(_master, _subaccount, _msgValue, callType, execData);

        if (handlerData.length > 0 && callType == CALLTYPE_BATCH) {
            uint8 actionType = abi.decode(handlerData, (uint8));
            if (actionType == ACTION_ORDER_CREATED) {
                revert Error.Position__BatchOrderNotAllowed();
            }
        }

        uint preBalance = address(token) != address(0) ? token.balanceOf(_subaccount) : 0;

        return abi.encode(token, preBalance, handlerData, handler);
    }

    function getNetValue(
        address _subaccount,
        IERC20 _baseToken,
        IStage[] calldata _stages,
        bytes32[][] calldata _positionKeys
    ) external view returns (uint value) {
        if (pendingOrderCount[_subaccount] != 0) {
            revert Error.Position__PendingOrdersExist();
        }

        for (uint i; i < _stages.length; i++) {
            IStage stage = _stages[i];
            bytes32[] calldata keys = _positionKeys[i];

            for (uint j; j < keys.length; j++) {
                if (!stage.verifyPositionOwner(keys[j], _subaccount)) {
                    revert Error.Position__NotPositionOwner();
                }
                value += stage.getPositionValue(keys[j], _baseToken);
            }
        }
    }

    // ============ Auth ============

    function processPostCall(address _subaccount, bytes calldata _hookData) external auth {
        if (_hookData.length == 0) return;

        (IERC20 token, uint preBalance, bytes memory handlerData, IStage handler) =
            abi.decode(_hookData, (IERC20, uint, bytes, IStage));

        uint postBalance = address(token) != address(0) ? token.balanceOf(_subaccount) : 0;
        handler.verify(_subaccount, token, preBalance, postBalance, handlerData);

        if (handlerData.length > 0) {
            uint8 actionType = abi.decode(handlerData, (uint8));

            if (actionType == ACTION_ORDER_CREATED) {
                (, bytes32 orderKey, bytes32 positionKey,) =
                    abi.decode(handlerData, (uint8, bytes32, bytes32, IERC20));
                pendingOrderCount[_subaccount]++;
                _logEvent("CreateOrder", abi.encode(_subaccount, orderKey, positionKey, handler, token));
            }
        }
    }

    function setHandler(address _target, IStage _handler) external auth {
        IStage oldHandler = handlers[_target];
        if (address(oldHandler) != address(0)) {
            validStages[oldHandler] = false;
        }

        handlers[_target] = _handler;
        if (address(_handler) != address(0)) {
            validStages[_handler] = true;
        }
    }

    function settleOrders(
        address _subaccount,
        IStage[] calldata _orderStages,
        bytes32[] calldata _orderKeys
    ) external auth {
        uint orderLen = _orderKeys.length;
        if (orderLen != _orderStages.length) {
            revert Error.Position__ArrayLengthMismatch();
        }

        for (uint i; i < orderLen; i++) {
            IStage stage = _orderStages[i];
            if (!validStages[stage]) revert Error.Position__InvalidStage();
            if (stage.isOrderPending(_orderKeys[i], _subaccount)) {
                revert Error.Position__OrderStillPending();
            }
        }

        uint pending = pendingOrderCount[_subaccount];
        pendingOrderCount[_subaccount] = pending > orderLen ? pending - orderLen : 0;

        _logEvent("SettleOrders", abi.encode(_subaccount, _orderKeys));
    }

    // ============ Internal ============

    function _setConfig(bytes memory) internal override {}
}
