// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";
import {StoreController} from "../../utils/StoreController.sol";
import {PuppetUtils} from "./../util/PuppetUtils.sol";

contract PuppetStore is StoreController {
    struct Rule {
        bytes32 positionKey;
        address trader;
        address puppet;
        uint stopLoss;
        uint throttleActivity;
        uint allowanceRate;
        uint expiry;
    }

    struct Activity {
        uint latestFunding;
        int pnl;
    }

    mapping(bytes32 puppetTraderKey => Rule) public ruleMap;
    mapping(bytes32 puppetTraderKey => Activity) public traderActivityMap;

    constructor(Authority _authority, address _initSetter) StoreController(_authority, _initSetter) {}

    function getRule(bytes32 _key) external view returns (Rule memory) {
        return ruleMap[_key];
    }

    function setRule(Rule memory _rule, bytes32 _key) external isSetter {
        ruleMap[_key] = _rule;
    }

    function removeRule(bytes32 _key) external isSetter {
        delete ruleMap[_key];
    }

    function getRuleList(address _trader, address[] calldata _addressList) external view returns (Rule[] memory) {
        uint _length = _addressList.length;
        Rule[] memory _rules = new Rule[](_addressList.length);
        for (uint i = 0; i < _length; i++) {
            bytes32 _key = PuppetUtils.getPuppetTraderKey(_addressList[i], _trader);

            _rules[i] = ruleMap[_key];
        }
        return _rules;
    }

    function setTraderActivity(bytes32 _key, Activity calldata _activity) external isSetter {
        traderActivityMap[_key] = _activity;
    }

    function getTraderActivity(bytes32 _key) external view returns (Activity memory) {
        return traderActivityMap[_key];
    }

    function setTraderActivityList(address _trader, address[] calldata _addressList, Activity[] calldata _activity) external isSetter {
        uint length = _addressList.length;
        if (length != _activity.length) revert PuppetStore__AddressListLengthMismatch();

        for (uint i = 0; i < length; i++) {
            bytes32 puppetTraderKey = PuppetUtils.getPuppetTraderKey(_addressList[i], _trader);
            traderActivityMap[puppetTraderKey] = _activity[i];
        }
    }

    function getTraderRuleAndActivityList(address _trader, address[] calldata _addressList)
        external
        view
        returns (Rule[] memory, Activity[] memory)
    {
        uint length = _addressList.length;

        Rule[] memory _rules = new Rule[](length);
        Activity[] memory _activity = new Activity[](length);

        for (uint i = 0; i < length; i++) {
            bytes32 puppetTraderKey = PuppetUtils.getPuppetTraderKey(_addressList[i], _trader);
            _rules[i] = ruleMap[puppetTraderKey];
            _activity[i] = traderActivityMap[puppetTraderKey];
        }
        return (_rules, _activity);
    }

    error PuppetStore__AddressListLengthMismatch();
}
