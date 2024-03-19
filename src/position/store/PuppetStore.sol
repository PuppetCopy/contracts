// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";
import {StoreController} from "../../utils/StoreController.sol";
import {PuppetUtils} from "./../util/PuppetUtils.sol";

contract PuppetStore is StoreController {
    struct Rule {
        uint throttleActivity;
        uint allowance;
        uint allowanceRate;
        uint expiry;
    }

    struct Activity {
        uint latestFunding;
        int pnl;
    }

    mapping(bytes32 ruleKey => Rule) public ruleMap;
    mapping(bytes32 ruleKey => Activity) public activityMap;

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
            bytes32 _key = PuppetUtils.getRuleKey(_addressList[i], routeKey);

            _rules[i] = ruleMap[_key];
        }
        return _rules;
    }

    function setRuleList(Rule[] calldata _rules, bytes32[] calldata _routeKeyList, address[] calldata _addressList) external isSetter {
        uint _length = _addressList.length;
        for (uint i = 0; i < _length; i++) {
            bytes32 _key = PuppetUtils.getRuleKey(_addressList[i], _routeKeyList[i]);

            ruleMap[_key] = _rules[i];
        }
    }

    function setActivity(bytes32 _key, Activity calldata _activity) external isSetter {
        activityMap[_key] = _activity;
    }

    function getActivity(bytes32 _key) external view returns (Activity memory) {
        return activityMap[_key];
    }

    function getActivityList(bytes32 _routeKey, address[] calldata _addressList) external view returns (Activity[] memory) {
        uint length = _addressList.length;
        Activity[] memory _activity = new Activity[](length);

        for (uint i = 0; i < length; i++) {
            bytes32 puppetTraderKey = PuppetUtils.getRuleKey(_addressList[i], _routeKey);
            _activity[i] = activityMap[puppetTraderKey];
        }
        return _activity;
    }

    function setRuleActivityList(bytes32 _routeKey, address[] calldata _addressList, Activity[] calldata _activityList) external isSetter {
        uint length = _addressList.length;

        for (uint i = 0; i < length; i++) {
            bytes32 puppetTraderKey = PuppetUtils.getRuleKey(_addressList[i], _routeKey);
            activityMap[puppetTraderKey] = _activityList[i];
        }
    }

    function getRuleAndActivityList(bytes32 _routeKey, address[] calldata _addressList) external view returns (Rule[] memory, Activity[] memory) {
        uint length = _addressList.length;

        Rule[] memory _rules = new Rule[](length);
        Activity[] memory _activity = new Activity[](length);

        for (uint i = 0; i < length; i++) {
            bytes32 rk = PuppetUtils.getRuleKey(_addressList[i], _routeKey);
            _rules[i] = ruleMap[rk];
            _activity[i] = activityMap[rk];
        }
        return (_rules, _activity);
    }
}
