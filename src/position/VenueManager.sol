// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC7579Account} from "modulekit/accounts/common/interfaces/IERC7579Account.sol";

import {CoreContract} from "../utils/CoreContract.sol";
import {Error} from "../utils/Error.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {IVenueValidator} from "./interface/IVenueValidator.sol";

contract VenueManager is CoreContract {
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

    function calcNetPositionsValue(
        IERC7579Account _subaccount,
        IERC20 _token,
        bytes32 _matchingKey
    ) external view returns (
        uint256 allocation,
        uint256 positionValue,
        uint256 netValue,
        PositionInfo[] memory positions
    ) {
        if (address(_subaccount) == address(0)) return (0, 0, 0, new PositionInfo[](0));

        allocation = _token.balanceOf(address(_subaccount));

        bytes32[] storage _keys = positionKeyListMap[_matchingKey];
        positions = new PositionInfo[](_keys.length);

        for (uint _i = 0; _i < _keys.length; ++_i) {
            bytes32 _positionKey = _keys[_i];
            Venue storage _venue = positionVenueMap[_positionKey];
            if (address(_venue.validator) == address(0)) revert Error.Allocation__VenueNotRegistered(_venue.venueKey);

            uint256 _npv = _venue.validator.getPositionNetValue(_positionKey);
            positionValue += _npv;

            positions[_i] = PositionInfo({
                venue: _venue,
                value: _npv,
                positionKey: _positionKey
            });
        }

        netValue = allocation + positionValue;
    }

    function _setConfig(bytes memory) internal override {}
}
