// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC7579Account, Execution} from "modulekit/accounts/common/interfaces/IERC7579Account.sol";
import {ModeLib, ModeCode, CallType, CALLTYPE_SINGLE, CALLTYPE_BATCH, CALLTYPE_STATIC} from "modulekit/accounts/common/lib/ModeLib.sol";
import {ExecutionLib} from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import {CoreContract} from "../utils/CoreContract.sol";
import {Error} from "../utils/Error.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {IVenueValidator} from "./interface/IVenueValidator.sol";
import {PositionUtils} from "./utils/PositionUtils.sol";

contract VenueRegistry is CoreContract {
    struct Venue {
        bytes32 venueKey;
        IVenueValidator validator;
    }

    struct PositionInfo {
        Venue venue;
        uint256 value;
        bytes32 positionKey;
    }

    mapping(bytes32 venueKey => IVenueValidator) public venueValidatorMap;
    mapping(address entrypoint => bytes32) public venueKeyMap;

    mapping(bytes32 matchingKey => bytes32[]) public positionKeyListMap;
    mapping(bytes32 positionKey => Venue) public positionVenueMap;

    constructor(IAuthority _authority) CoreContract(_authority, "") {}

    function getVenue(address _entrypoint) external view returns (Venue memory _venue) {
        _venue.venueKey = venueKeyMap[_entrypoint];
        _venue.validator = venueValidatorMap[_venue.venueKey];
    }

    function getVenueByTarget(address _target) external view returns (Venue memory _venue) {
        _venue.venueKey = venueKeyMap[_target];
        _venue.validator = venueValidatorMap[_venue.venueKey];
        if (address(_venue.validator) == address(0)) revert Error.VenueRegistry__VenueNotRegistered(_venue.venueKey);
    }

    // ============ Hook Validation ============

    /// @notice Validate before execution, parse msgData and route to venue validator
    function validatePreCall(
        address _subaccount,
        address,
        uint256,
        bytes calldata _msgData
    ) external view returns (bytes memory hookData) {
        if (_msgData.length < 4) return "";

        // Only validate execute() calls
        if (bytes4(_msgData[:4]) != IERC7579Account.execute.selector) return "";

        ModeCode mode = ModeCode.wrap(bytes32(_msgData[4:36]));
        CallType callType = ModeLib.getCallType(mode);
        bytes calldata executionData = _msgData[36:];

        // Static calls are read-only, allow
        if (callType == CALLTYPE_STATIC) return "";

        if (callType == CALLTYPE_SINGLE) {
            (address target, uint256 value, bytes calldata callData) = ExecutionLib.decodeSingle(executionData);
            IVenueValidator validator = _getValidator(target);
            bytes memory venueHookData = validator.validatePreCallSingle(_subaccount, target, value, callData);
            if (venueHookData.length == 0) return "";
            return abi.encode(target, venueHookData);
        }

        if (callType == CALLTYPE_BATCH) {
            Execution[] calldata executions = ExecutionLib.decodeBatch(executionData);
            if (executions.length == 0) return "";
            // Route to venue based on first execution's target (batch goes to same venue)
            address target = executions[0].target;
            IVenueValidator validator = _getValidator(target);
            bytes memory venueHookData = validator.validatePreCallBatch(_subaccount, executions);
            if (venueHookData.length == 0) return "";
            return abi.encode(target, venueHookData);
        }

        // Block DELEGATECALL and unknown call types
        revert Error.VenueRegistry__InvalidCallType();
    }

    /// @notice Process after execution using hookData from preCheck (can mutate state)
    function processPostCall(
        address _subaccount,
        bytes calldata _hookData
    ) external {
        if (_hookData.length == 0) return;

        // hookData contains venue address + venue-specific data
        (address venueTarget, bytes memory venueHookData) = abi.decode(_hookData, (address, bytes));
        bytes32 venueKey = venueKeyMap[venueTarget];
        IVenueValidator validator = venueValidatorMap[venueKey];
        if (address(validator) == address(0)) revert Error.VenueRegistry__VenueNotRegistered(venueKey);

        validator.processPostCall(_subaccount, venueHookData);

        _logEvent("ProcessPostCall", abi.encode(
            _subaccount,
            venueTarget,
            venueKey,
            venueHookData
        ));
    }

    function _getValidator(address _target) internal view returns (IVenueValidator validator) {
        bytes32 venueKey = venueKeyMap[_target];
        validator = venueValidatorMap[venueKey];
        if (address(validator) == address(0)) revert Error.VenueRegistry__VenueNotRegistered(venueKey);
    }

    function getValidator(bytes32 _venueKey) external view returns (IVenueValidator) {
        return venueValidatorMap[_venueKey];
    }

    function getPositionKeyList(bytes32 _matchingKey) external view returns (bytes32[] memory) {
        return positionKeyListMap[_matchingKey];
    }

    function setVenue(bytes32 _venueKey, IVenueValidator _validator, address[] calldata _entrypoints) external auth {
        venueValidatorMap[_venueKey] = _validator;
        for (uint _i = 0; _i < _entrypoints.length; ++_i) {
            venueKeyMap[_entrypoints[_i]] = _venueKey;
        }
        _logEvent("SetVenue", abi.encode(_venueKey, _validator, _entrypoints));
    }

    function updatePosition(
        bytes32 _matchingKey,
        bytes32 _positionKey,
        Venue calldata _venue,
        uint256 _netValue
    ) external auth {
        if (_netValue > 0 && positionVenueMap[_positionKey].venueKey == bytes32(0)) {
            positionKeyListMap[_matchingKey].push(_positionKey);
            positionVenueMap[_positionKey] = _venue;
        } else if (_netValue == 0 && _positionKey != bytes32(0)) {
            bytes32[] storage _keys = positionKeyListMap[_matchingKey];
            for (uint _i = 0; _i < _keys.length; ++_i) {
                if (_keys[_i] == _positionKey) {
                    _keys[_i] = _keys[_keys.length - 1];
                    _keys.pop();
                    delete positionVenueMap[_positionKey];
                    break;
                }
            }
        }
    }

    function getNetValue(IERC20 _token, IERC7579Account _subaccount) external view returns (uint256) {
        bytes32 _matchingKey = PositionUtils.getMatchingKey(_token, _subaccount);
        uint256 _netValue = _token.balanceOf(address(_subaccount));

        bytes32[] storage _keys = positionKeyListMap[_matchingKey];
        for (uint _i = 0; _i < _keys.length; ++_i) {
            _netValue += positionVenueMap[_keys[_i]].validator.getPositionNetValue(_keys[_i]);
        }

        return _netValue;
    }

    function snapshotNetValue(bytes32 _matchingKey) external view returns (uint256 _positionValue, PositionInfo[] memory _positions) {
        bytes32[] storage _keys = positionKeyListMap[_matchingKey];
        _positions = new PositionInfo[](_keys.length);

        for (uint _i = 0; _i < _keys.length; ++_i) {
            bytes32 _positionKey = _keys[_i];
            Venue storage _venue = positionVenueMap[_positionKey];
            if (address(_venue.validator) == address(0)) revert Error.VenueRegistry__VenueNotRegistered(_venue.venueKey);

            uint256 _npv = _venue.validator.getPositionNetValue(_positionKey);
            _positionValue += _npv;

            _positions[_i] = PositionInfo({
                venue: _venue,
                value: _npv,
                positionKey: _positionKey
            });
        }
    }

    function _setConfig(bytes memory) internal override {}
}
