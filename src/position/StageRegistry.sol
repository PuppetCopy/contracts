// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC7579Account} from "modulekit/accounts/common/interfaces/IERC7579Account.sol";
import {ModeLib, ModeCode, CallType, CALLTYPE_SINGLE, CALLTYPE_DELEGATECALL} from "modulekit/accounts/common/lib/ModeLib.sol";
import {ExecutionLib} from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import {CoreContract} from "../utils/CoreContract.sol";
import {Error} from "../utils/Error.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {IStage} from "./interface/IStage.sol";
import {PositionUtils} from "./utils/PositionUtils.sol";

/// @title StageRegistry
/// @notice Lean passthrough that routes actions to stage handlers
/// @dev Complexity lives in handlers (GmxStage, HyperliquidStage, etc.)
contract StageRegistry is CoreContract {
    // ============ Constants ============

    bytes32 public constant OPEN = keccak256("OPEN");
    bytes32 public constant CLOSE = keccak256("CLOSE");

    // ============ State ============

    /// @notice Stage to handler mapping
    mapping(bytes32 stage => IStage) public handlers;

    /// @notice Position tracking for net value calculations
    mapping(bytes32 matchingKey => bytes32[]) public positionKeys;
    mapping(bytes32 positionKey => bytes32) public positionStage;

    // ============ Constructor ============

    constructor(IAuthority _authority) CoreContract(_authority, "") {}

    // ============ Hook Validation ============

    /// @notice Validate action before execution
    /// @dev Called by MasterHook.preCheck via UserRouter
    function validatePreCall(address _subaccount, address, uint, bytes calldata _msgData)
        external
        view
        returns (bytes memory hookData)
    {
        if (_msgData.length < 4) return "";

        // Only validate execute() calls
        if (bytes4(_msgData[:4]) != IERC7579Account.execute.selector) return "";

        ModeCode mode = ModeCode.wrap(bytes32(_msgData[4:36]));
        CallType callType = ModeLib.getCallType(mode);

        // Block delegatecall
        if (callType == CALLTYPE_DELEGATECALL) revert Error.StageRegistry__DelegateCallBlocked();

        // Only validate single execution (stages use explicit action format)
        if (callType != CALLTYPE_SINGLE) return "";

        bytes calldata execData = _msgData[36:];
        (, , bytes calldata callData) = ExecutionLib.decodeSingle(execData);

        // Decode: action, stage, data
        if (callData.length < 64) return "";
        bytes32 action = bytes32(callData[:32]);
        bytes32 stage = bytes32(callData[32:64]);
        bytes calldata data = callData[64:];

        // Route to handler
        IStage handler = handlers[stage];
        if (address(handler) == address(0)) revert Error.StageRegistry__UnknownStage(stage);

        bytes32 positionKey;
        bytes memory handlerData;
        if (action == OPEN) {
            (positionKey, handlerData) = handler.open(_subaccount, data);
        } else if (action == CLOSE) {
            (positionKey, handlerData) = handler.close(_subaccount, data);
        } else {
            revert Error.StageRegistry__InvalidAction(action);
        }

        if (handlerData.length == 0) return "";
        return abi.encode(action, stage, positionKey, handlerData);
    }

    /// @notice Settle after execution
    function settle(address _subaccount, bytes calldata _hookData) external {
        if (_hookData.length == 0) return;

        (bytes32 action, bytes32 stage, bytes32 positionKey, bytes memory hookData) =
            abi.decode(_hookData, (bytes32, bytes32, bytes32, bytes));

        IStage handler = handlers[stage];
        if (address(handler) == address(0)) revert Error.StageRegistry__UnknownStage(stage);

        handler.settle(_subaccount, positionKey, hookData);

        _logEvent("Settle", abi.encode(_subaccount, action, stage, positionKey));
    }

    // ============ Position Tracking ============

    function getPositionKeyList(bytes32 _matchingKey) external view returns (bytes32[] memory) {
        return positionKeys[_matchingKey];
    }

    function updatePosition(bytes32 _matchingKey, bytes32 _positionKey, bytes32 _stage, uint _value)
        external
        auth
    {
        if (_value > 0 && positionStage[_positionKey] == bytes32(0)) {
            // New position
            positionKeys[_matchingKey].push(_positionKey);
            positionStage[_positionKey] = _stage;
        } else if (_value == 0 && positionStage[_positionKey] != bytes32(0)) {
            // Position closed - remove from list
            bytes32[] storage keys = positionKeys[_matchingKey];
            for (uint i = 0; i < keys.length; ++i) {
                if (keys[i] == _positionKey) {
                    keys[i] = keys[keys.length - 1];
                    keys.pop();
                    delete positionStage[_positionKey];
                    break;
                }
            }
        }
    }

    /// @notice Get total net value (token balance + position values)
    function getNetValue(IERC20 _token, IERC7579Account _subaccount) external view returns (uint) {
        bytes32 matchingKey = PositionUtils.getMatchingKey(_token, _subaccount);
        uint netValue = _token.balanceOf(address(_subaccount));

        bytes32[] storage keys = positionKeys[matchingKey];
        for (uint i = 0; i < keys.length; ++i) {
            bytes32 posKey = keys[i];
            bytes32 stage = positionStage[posKey];
            IStage handler = handlers[stage];
            netValue += handler.getValue(posKey);
        }

        return netValue;
    }

    // ============ Admin ============

    function setHandler(bytes32 _stage, IStage _handler) external auth {
        handlers[_stage] = _handler;
        _logEvent("SetHandler", abi.encode(_stage, _handler));
    }

    function _setConfig(bytes memory) internal override {}
}
