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
/// @notice Routes execute() calls to stage stageMap for validation and tracks pending orders
contract Position is CoreContract {
    // ============ Constants ============

    uint8 public constant ACTION_NONE = 0;
    uint8 public constant ACTION_ORDER_CREATED = 1;

    // ============ State ============

    mapping(address target => IStage) public stageMap;
    mapping(IStage stage => bool) public validStages;
    mapping(IERC7579Account master => uint) public pendingOrderCount;

    // ============ Constructor ============

    constructor(IAuthority _authority) CoreContract(_authority, "") {}

    // ============ Views ============

    function processPreCall(address _msgSender, IERC7579Account _master, uint _msgValue, bytes calldata _msgData)
        external
        view
        returns (bytes memory _hookData)
    {
        if (_msgData.length < 4) return "";
        if (bytes4(_msgData[:4]) != IERC7579Account.execute.selector) return "";

        ModeCode _mode = ModeCode.wrap(bytes32(_msgData[4:36]));
        CallType _callType = ModeLib.getCallType(_mode);

        if (_callType == CALLTYPE_DELEGATECALL) revert Error.Position__DelegateCallBlocked();
        if (_callType != CALLTYPE_SINGLE && _callType != CALLTYPE_BATCH) return "";

        bytes calldata _execData = _msgData[36:];

        address _firstTarget = address(bytes20(_execData[:20]));
        IStage _handler = stageMap[_firstTarget];
        if (address(_handler) == address(0)) return "";

        (IERC20 _token, bytes memory _handlerData) = _handler.validate(_msgSender, _master, _msgValue, _callType, _execData);

        if (_handlerData.length > 0 && _callType == CALLTYPE_BATCH) {
            uint8 _actionType = abi.decode(_handlerData, (uint8));
            if (_actionType == ACTION_ORDER_CREATED) {
                revert Error.Position__BatchOrderNotAllowed();
            }
        }

        uint _preBalance = address(_token) != address(0) ? _token.balanceOf(address(_master)) : 0;

        return abi.encode(_token, _preBalance, _handlerData, _handler, _msgData);
    }

    function getNetValue(
        IERC7579Account _master,
        IERC20 _baseToken,
        IStage[] calldata _stages,
        bytes32[][] calldata _positionKeys
    ) external view returns (uint _value) {
        if (pendingOrderCount[_master] != 0) {
            revert Error.Position__PendingOrdersExist();
        }

        for (uint _i; _i < _stages.length; _i++) {
            IStage _stage = _stages[_i];
            bytes32[] calldata _keys = _positionKeys[_i];

            for (uint _j; _j < _keys.length; _j++) {
                if (!_stage.verifyPositionOwner(_keys[_j], _master)) {
                    revert Error.Position__NotPositionOwner();
                }
                _value += _stage.getPositionValue(_keys[_j], _baseToken);
            }
        }
    }

    // ============ Auth ============

    function processPostCall(IERC7579Account _master, bytes calldata _hookData) external auth {
        if (_hookData.length == 0) return;

        (IERC20 _token, uint _preBalance, bytes memory _handlerData, IStage _handler, bytes memory _calldata) =
            abi.decode(_hookData, (IERC20, uint, bytes, IStage, bytes));

        uint _postBalance = address(_token) != address(0) ? _token.balanceOf(address(_master)) : 0;
        _handler.verify(_master, _token, _preBalance, _postBalance, _handlerData);

        if (_handlerData.length > 0) {
            uint8 _actionType = abi.decode(_handlerData, (uint8));

            if (_actionType == ACTION_ORDER_CREATED) {
                (, bytes32 _orderKey, bytes32 _positionKey,) =
                    abi.decode(_handlerData, (uint8, bytes32, bytes32, IERC20));
                uint _pendingCount = ++pendingOrderCount[_master];
                _logEvent("CreateOrder", abi.encode(_master, _orderKey, _positionKey, _handler, _token, _pendingCount, _calldata));
            }
        }
    }

    function setStage(address _target, IStage _stage) external auth {
        IStage _oldStage = stageMap[_target];
        if (address(_oldStage) != address(0)) {
            validStages[_oldStage] = false;
        }

        stageMap[_target] = _stage;
        if (address(_stage) != address(0)) {
            validStages[_stage] = true;
        }

        _logEvent("SetStage", abi.encode(_target, _oldStage, _stage));
    }

    function settleOrders(
        IERC7579Account _master,
        IStage[] calldata _orderStages,
        bytes32[] calldata _orderKeys
    ) external auth {
        uint _orderLen = _orderKeys.length;
        if (_orderLen != _orderStages.length) {
            revert Error.Position__ArrayLengthMismatch();
        }

        for (uint _i; _i < _orderLen; _i++) {
            IStage _stage = _orderStages[_i];
            if (!validStages[_stage]) revert Error.Position__InvalidStage();
            if (_stage.isOrderPending(_orderKeys[_i], _master)) {
                revert Error.Position__OrderStillPending();
            }
        }

        uint _pending = pendingOrderCount[_master];
        uint _pendingCount = _pending > _orderLen ? _pending - _orderLen : 0;
        pendingOrderCount[_master] = _pendingCount;

        _logEvent("SettleOrders", abi.encode(_master, _orderKeys, _pendingCount));
    }

    // ============ Internal ============

    function _setConfig(bytes memory) internal override {}
}
