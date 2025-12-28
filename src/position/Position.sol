// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC7579Account} from "modulekit/accounts/common/interfaces/IERC7579Account.sol";

import {CoreContract} from "../utils/CoreContract.sol";
import {Error} from "../utils/Error.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {IVenueValidator} from "./interface/IVenueValidator.sol";
import {PositionUtils} from "./utils/PositionUtils.sol";

contract Position is CoreContract {
    enum IntentType { MasterDeposit, Allocate, Withdraw, Order }

    struct CallIntent {
        IntentType intentType;
        address account;
        IERC7579Account subaccount;
        IERC20 token;
        uint256 amount;
        uint256 acceptableNetValue;
        uint256 deadline;
        uint256 nonce;
    }

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

    function snapshotPositionValue(
        CallIntent calldata _intent
    ) external returns (
        bytes32 matchingKey,
        uint256 allocation,
        uint256 positionValue,
        uint256 netValue,
        PositionInfo[] memory positions
    ) {
        if (address(_intent.subaccount) == address(0)) return (bytes32(0), 0, 0, 0, new PositionInfo[](0));

        matchingKey = PositionUtils.getMatchingKey(_intent.token, _intent.subaccount);
        allocation = _intent.token.balanceOf(address(_intent.subaccount));

        bytes32[] storage _keys = positionKeyListMap[matchingKey];
        positions = new PositionInfo[](_keys.length);

        for (uint _i = 0; _i < _keys.length; ++_i) {
            bytes32 _positionKey = _keys[_i];
            Venue storage _venue = positionVenueMap[_positionKey];
            if (address(_venue.validator) == address(0)) revert Error.Position__VenueNotRegistered(_venue.venueKey);

            uint256 _npv = _venue.validator.getPositionNetValue(_positionKey);
            positionValue += _npv;

            positions[_i] = PositionInfo({
                venue: _venue,
                value: _npv,
                positionKey: _positionKey
            });
        }

        netValue = allocation + positionValue;

        if (_intent.acceptableNetValue > 0 && netValue < _intent.acceptableNetValue) {
            revert Error.Position__NetValueBelowAcceptable(netValue, _intent.acceptableNetValue);
        }

        _logEvent("SnapshotPositionValue", abi.encode(
            _intent,
            matchingKey,
            allocation,
            positionValue,
            netValue,
            positions
        ));
    }

    function _setConfig(bytes memory) internal override {}
}
