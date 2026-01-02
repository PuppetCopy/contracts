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
/// @notice Routes raw execute() calls to stage handlers for validation
contract Position is CoreContract {
    /// @notice Target address to stage handler mapping
    mapping(address target => IStage) public handlers;

    constructor(IAuthority _authority) CoreContract(_authority, "") {}

    /// @notice Validate execute() before execution
    /// @dev Token is extracted by handler from execution data, not passed as parameter
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

        // Extract first target for routing
        address firstTarget = address(bytes20(execData[:20]));
        IStage handler = handlers[firstTarget];
        if (address(handler) == address(0)) return "";

        // Handler extracts and returns the token from execution data
        (IERC20 token, bytes memory handlerData) = handler.validate(_master, _subaccount, _msgValue, callType, execData);

        // Track balance if token specified (claims may return address(0))
        uint preBalance = address(token) != address(0) ? token.balanceOf(_subaccount) : 0;

        return abi.encode(token, preBalance, handlerData, handler);
    }

    /// @notice Verify state after execution
    function processPostCall(address _subaccount, bytes calldata _hookData) external view {
        if (_hookData.length == 0) return;

        (IERC20 token, uint preBalance, bytes memory handlerData, IStage handler) =
            abi.decode(_hookData, (IERC20, uint, bytes, IStage));

        // Skip balance tracking if no token (e.g., claims)
        uint postBalance = address(token) != address(0) ? token.balanceOf(_subaccount) : 0;
        handler.verify(_subaccount, token, preBalance, postBalance, handlerData);
    }

    /// @notice Record position outcome (called after execution)
    function settle(address _subaccount, bytes calldata _handlerData) external auth {
        // Handler address encoded in handlerData by validate()
        (,, , IStage handler) = abi.decode(_handlerData, (IERC20, uint, bytes, IStage));
        handler.settle(_subaccount, _handlerData);
    }

    function setHandler(address _target, IStage _handler) external auth {
        handlers[_target] = _handler;
    }

    /// @notice Get net value (token balance only for now)
    /// @dev Position tracking to be added later
    function getNetValue(IERC20 _token, IERC7579Account _subaccount) external view returns (uint) {
        return _token.balanceOf(address(_subaccount));
    }

    /// @notice Get position keys for a matching key
    /// @dev Position tracking to be added later
    function getPositionKeyList(bytes32) external pure returns (bytes32[] memory) {
        return new bytes32[](0);
    }

    function _setConfig(bytes memory) internal override {}
}
