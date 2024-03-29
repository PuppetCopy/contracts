// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";

import {StoreController} from "./../../utils/StoreController.sol";
import {PositionUtils} from "./../util/PositionUtils.sol";

contract PuppetStore is StoreController {
    struct Rule {
        uint throttleActivity;
        uint allowanceRate;
        uint expiry;
    }

    mapping(address token => uint) public tokenAllowanceCapMap;

    mapping(bytes32 ruleKey => Rule) public ruleMap; // ruleKey = keccak256(collateralToken, puppet, trader)
    mapping(bytes32 fundingActivityKey => uint) public tradeFundingActivityMap; // fundingActivityKey = keccak256(puppet, trader)
    mapping(bytes32 allowanceKey => uint) tokenAllowanceActivityMap; // allowanceKey = keccak256(collateralToken, puppet)

    constructor(Authority _authority, address _initSetter) StoreController(_authority, _initSetter) {}

    function getRule(bytes32 _key) external view returns (Rule memory) {
        return ruleMap[_key];
    }

    function setRule(Rule memory _rule, bytes32 _key) external isSetter {
        ruleMap[_key] = _rule;
    }

    function getRuleList(bytes32[] calldata _keyList) external view returns (Rule[] memory) {
        uint _length = _keyList.length;
        Rule[] memory _rules = new Rule[](_keyList.length);
        for (uint i = 0; i < _length; i++) {
            _rules[i] = ruleMap[_keyList[i]];
        }
        return _rules;
    }

    function setRuleList(Rule[] calldata _rules, bytes32[] calldata _keyList) external isSetter {
        uint _length = _keyList.length;
        for (uint i = 0; i < _length; i++) {
            ruleMap[_keyList[i]] = _rules[i];
        }
    }

    function getActivityList(bytes32[] calldata _keyList) external view returns (uint[] memory) {
        uint _length = _keyList.length;
        uint[] memory _activities = new uint[](_keyList.length);
        for (uint i = 0; i < _length; i++) {
            _activities[i] = tradeFundingActivityMap[_keyList[i]];
        }
        return _activities;
    }

    function setActivityList(bytes32[] memory _keyList, uint[] calldata _amountList) external isSetter {
        uint _length = _keyList.length;
        for (uint i = 0; i < _length; i++) {
            tradeFundingActivityMap[_keyList[i]] = _amountList[i];
        }
    }

    function getTokenAllowanceActivity(bytes32 _key) external view returns (uint) {
        return tokenAllowanceActivityMap[_key];
    }

    function setTokenAllowanceActivity(bytes32 _key, uint _allowance) external isSetter {
        tokenAllowanceActivityMap[_key] = _allowance;
    }

    function setActivity(bytes32 _key, uint _time) external isSetter {
        tradeFundingActivityMap[_key] = _time;
    }

    function getActivity(bytes32 _key) external view returns (uint) {
        return tradeFundingActivityMap[_key];
    }

    function getMatchingActivity(address collateralToken, address trader, address[] calldata _puppetList)
        external
        view
        returns (Rule[] memory _ruleList, uint[] memory _activityList, uint[] memory _allowanceOptimList)
    {
        uint length = _puppetList.length;

        _ruleList = new Rule[](length);
        _activityList = new uint[](length);
        _allowanceOptimList = new uint[](length);

        for (uint i = 0; i < length; i++) {
            _ruleList[i] = ruleMap[PositionUtils.getRuleKey(collateralToken, _puppetList[i], trader)];
            _activityList[i] = tradeFundingActivityMap[PositionUtils.getFundingActivityKey(_puppetList[i], trader)];
            _allowanceOptimList[i] = tokenAllowanceActivityMap[PositionUtils.getAllownaceKey(collateralToken, _puppetList[i])];
        }
        return (_ruleList, _activityList, _allowanceOptimList);
    }

    function setMatchingActivity(
        address collateralToken,
        address trader,
        address[] calldata _puppetList,
        uint[] calldata _activityList,
        uint[] calldata _sampledAllowanceList
    ) external isSetter {
        uint length = _puppetList.length;

        for (uint i = 0; i < length; i++) {
            tradeFundingActivityMap[PositionUtils.getFundingActivityKey(_puppetList[i], trader)] = _activityList[i];
            tokenAllowanceActivityMap[PositionUtils.getAllownaceKey(collateralToken, _puppetList[i])] = _sampledAllowanceList[i];
        }
    }

    function getTokenAllowanceCap(address _token) external view returns (uint) {
        return tokenAllowanceCapMap[_token];
    }

    function setTokenAllowanceCap(address _token, uint _amount) external isSetter {
        tokenAllowanceCapMap[_token] = _amount;
    }

    error PuppetStore__InvalidAmount();
}
