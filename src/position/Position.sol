// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC7579Account} from "modulekit/accounts/common/interfaces/IERC7579Account.sol";
import {ModeLib, ModeCode, CallType, CALLTYPE_SINGLE, CALLTYPE_BATCH, CALLTYPE_DELEGATECALL} from "modulekit/accounts/common/lib/ModeLib.sol";

import {CoreContract} from "../utils/CoreContract.sol";
import {Error} from "../utils/Error.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {IStage, Action} from "./interface/IStage.sol";
import {Registry} from "../account/Registry.sol";

/// @title Position
/// @notice Routes execute() calls to stage stageMap for validation and tracks pending orders
contract Position is CoreContract {
    // ============ State ============

    mapping(address target => IStage) public stageMap;
    mapping(IStage stage => bool) public validStages;
    mapping(IERC7579Account master => uint) public pendingOrderCount;

    // ============ Constructor ============

    constructor(IAuthority _authority) CoreContract(_authority, "") {}

    // ============ Hook ============

    function processPreCall(
        Registry _registry,
        address _caller,
        IERC7579Account _master,
        uint _callValue,
        bytes calldata _callData
    ) external auth returns (bytes memory _hookData) {
        IERC20 _baseToken = _registry.getMasterInfo(_master).baseToken;

        if (address(_baseToken) == address(0)) revert Error.Position__InvalidBaseToken();
        if (_callData.length < 4) return "";
        if (bytes4(_callData[:4]) != IERC7579Account.execute.selector) return "";

        ModeCode _mode = ModeCode.wrap(bytes32(_callData[4:36]));
        CallType _callType = ModeLib.getCallType(_mode);

        if (_callType == CALLTYPE_DELEGATECALL) revert Error.Position__DelegateCallBlocked();
        if (_callType != CALLTYPE_SINGLE && _callType != CALLTYPE_BATCH) return "";

        bytes calldata _execData = _callData[36:];

        address _firstTarget = address(bytes20(_execData[:20]));
        IStage _handler = stageMap[_firstTarget];
        if (address(_handler) == address(0)) return "";

        Action memory _action = _handler.getAction(_caller, _master, _baseToken, _callValue, _callType, _execData);
        if (_action.actionType == bytes4(0)) revert Error.Position__InvalidAction();

        // Order-creating actions have data (orderKey, positionKey) - not allowed in batch
        if (_action.data.length > 0 && _callType == CALLTYPE_BATCH) {
            revert Error.Position__BatchOrderNotAllowed();
        }

        uint _preBalance = _baseToken.balanceOf(address(_master));

        // Log pre-call event with calldata directly (avoids passing through hookData memory)
        _logEvent("MasterPreCall", abi.encode(_caller, _master, _handler, _callData));

        // Return hookData - includes baseToken for post-call
        return abi.encode(_baseToken, _handler, _action, _preBalance);
    }

    function processPostCall(
        IERC7579Account _master,
        bytes calldata _hookData
    ) external auth {
        if (_hookData.length == 0) return;

        (IERC20 _baseToken, IStage _handler, Action memory _action, uint _preBalance) =
            abi.decode(_hookData, (IERC20, IStage, Action, uint));

        uint _postBalance = _baseToken.balanceOf(address(_master));
        _handler.verify(_master, _baseToken, _preBalance, _postBalance, _action.data);

        // Extract order details if present (order-creating actions have data)
        bytes32 _orderKey;
        bytes32 _positionKey;
        uint _pendingCount = pendingOrderCount[_master];

        if (_action.data.length > 0) {
            (_orderKey, _positionKey) = abi.decode(_action.data, (bytes32, bytes32));
            _pendingCount = ++pendingOrderCount[_master];
        }

        // Post-call event with balance state and order details (calldata logged in MasterPreCall)
        _logEvent("MasterPostCall", abi.encode(
            _master,
            _handler,
            _baseToken,
            _preBalance,
            _postBalance,
            _action.actionType,
            _orderKey,
            _positionKey,
            _pendingCount
        ));
    }

    function getNetValue(
        IERC7579Account _master,
        IERC20 _baseToken,
        IStage[] calldata _stageList,
        bytes32[][] calldata _positionKeyList
    ) external view returns (uint _value) {
        if (pendingOrderCount[_master] != 0) {
            revert Error.Position__PendingOrdersExist();
        }

        for (uint _i; _i < _stageList.length; _i++) {
            IStage _stage = _stageList[_i];
            bytes32[] calldata _keys = _positionKeyList[_i];

            for (uint _j; _j < _keys.length; _j++) {
                if (!_stage.verifyPositionOwner(_keys[_j], _master)) {
                    revert Error.Position__NotPositionOwner();
                }
                _value += _stage.getPositionValue(_keys[_j], _baseToken);
            }
        }
    }

    // ============ Auth ============

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
        IStage[] calldata _stageList,
        bytes32[] calldata _orderKeyList
    ) external auth {
        uint _len = _orderKeyList.length;
        if (_len != _stageList.length) {
            revert Error.Position__ArrayLengthMismatch();
        }

        for (uint _i; _i < _len; _i++) {
            IStage _stage = _stageList[_i];
            if (!validStages[_stage]) revert Error.Position__InvalidStage();
            if (_stage.isOrderPending(_orderKeyList[_i], _master)) {
                revert Error.Position__OrderStillPending();
            }
        }

        uint _pending = pendingOrderCount[_master];
        uint _pendingCount = _pending > _len ? _pending - _len : 0;
        pendingOrderCount[_master] = _pendingCount;

        _logEvent("SettleOrders", abi.encode(_master, _orderKeyList, _pendingCount));
    }

    // ============ Internal ============

    function _setConfig(bytes memory) internal override {}
}
