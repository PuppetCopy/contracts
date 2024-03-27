// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";

import {StoreController} from "../../utils/StoreController.sol";
import {PositionUtils} from "./../util/PositionUtils.sol";

contract PuppetStore is StoreController {
    struct Rule {
        address trader;
        address collateralToken;
        uint throttleActivity;
        uint allowance;
        uint allowanceRate;
        uint expiry;
    }

    mapping(bytes32 ruleKey => Rule) public ruleMap;

    constructor(Authority _authority, address _initSetter) StoreController(_authority, _initSetter) {}

    function getRule(bytes32 _key) external view returns (Rule memory) {
        return ruleMap[_key];
    }

    function setRule(Rule memory _rule, bytes32 _key) external isSetter {
        ruleMap[_key] = _rule;
    }

    function getRuleList(bytes32 routeKey, address[] calldata _addressList) external view returns (Rule[] memory) {
        uint _length = _addressList.length;
        Rule[] memory _rules = new Rule[](_addressList.length);
        for (uint i = 0; i < _length; i++) {
            bytes32 _key = PositionUtils.getRuleKey(_addressList[i], routeKey);

            _rules[i] = ruleMap[_key];
        }
        return _rules;
    }

    function setRuleList(Rule[] calldata _rules, bytes32[] calldata _routeKeyList, address[] calldata _addressList) external isSetter {
        uint _length = _addressList.length;
        for (uint i = 0; i < _length; i++) {
            bytes32 _key = PositionUtils.getRuleKey(_addressList[i], _routeKeyList[i]);

            ruleMap[_key] = _rules[i];
        }
    }
}
