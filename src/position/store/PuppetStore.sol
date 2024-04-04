// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {StoreController} from "./../../utils/StoreController.sol";
import {PositionUtils} from "./../util/PositionUtils.sol";

contract PuppetStore is StoreController {
    struct Rule {
        uint throttleActivity;
        uint allowanceRate;
        uint expiry;
    }

    mapping(IERC20 token => uint) public tokenAllowanceCapMap;

    mapping(address puppet => mapping(IERC20 token => uint) name) balanceMap;

    mapping(bytes32 ruleKey => Rule) public ruleMap; // ruleKey = keccak256(collateralToken, puppet, trader)

    mapping(address puppet => mapping(address trader => uint) name) public fundingActivityMap;

    constructor(Authority _authority, address _initSetter) StoreController(_authority, _initSetter) {}

    function getTokenAllowanceCap(IERC20 _token) external view returns (uint) {
        return tokenAllowanceCapMap[_token];
    }

    function setTokenAllowanceCap(IERC20 _token, uint _amount) external isSetter {
        tokenAllowanceCapMap[_token] = _amount;
    }

    function getBalance(IERC20 _token, address _account) external view returns (uint) {
        return balanceMap[_account][_token];
    }

    function setBalance(IERC20 _token, address _account, uint _amount) external isSetter {
        balanceMap[_account][_token] = _amount;
    }

    function getRule(bytes32 _key) external view returns (Rule memory) {
        return ruleMap[_key];
    }

    function setRule(bytes32 _key, Rule calldata _rule) external isSetter {
        ruleMap[_key] = _rule;
    }

    function getBalanceList(IERC20 _token, address[] calldata _accountList) external view returns (uint[] memory) {
        uint _accountListLength = _accountList.length;
        uint[] memory _balanceList = new uint[](_accountListLength);
        for (uint i = 0; i < _accountListLength; i++) {
            _balanceList[i] = balanceMap[_accountList[i]][_token];
        }
        return _balanceList;
    }

    function setBalanceList(IERC20 _token, address[] calldata _accountList, uint[] calldata _balanceList) external isSetter {
        uint _accountListLength = _accountList.length;

        if (_accountListLength != _balanceList.length) revert PuppetStore__InvalidLength();

        for (uint i = 0; i < _accountListLength; i++) {
            balanceMap[_accountList[i]][_token] = _balanceList[i];
        }
    }

    function getRuleList(bytes32[] calldata _keyList) external view returns (Rule[] memory) {
        uint _keyListLength = _keyList.length;
        Rule[] memory _rules = new Rule[](_keyList.length);
        for (uint i = 0; i < _keyListLength; i++) {
            _rules[i] = ruleMap[_keyList[i]];
        }
        return _rules;
    }

    function setRuleList(bytes32[] calldata _keyList, Rule[] calldata _rules) external isSetter {
        uint _keyListLength = _keyList.length;
        uint _ruleLength = _rules.length;

        if (_keyListLength != _ruleLength) revert PuppetStore__InvalidLength();

        for (uint i = 0; i < _keyListLength; i++) {
            ruleMap[_keyList[i]] = _rules[i];
        }
    }

    function getFundingActivityList(address trader, address[] calldata puppetList) external view returns (uint[] memory) {
        uint _puppetListLength = puppetList.length;
        uint[] memory fundingActivityList = new uint[](_puppetListLength);
        for (uint i = 0; i < _puppetListLength; i++) {
            fundingActivityList[i] = fundingActivityMap[puppetList[i]][trader];
        }
        return fundingActivityList;
    }

    function setFundingActivityList(address trader, address[] calldata puppetList, uint[] calldata _timeList) external isSetter {
        uint _puppetListLength = puppetList.length;

        if (_puppetListLength != _timeList.length) revert PuppetStore__InvalidLength();

        for (uint i = 0; i < _puppetListLength; i++) {
            fundingActivityMap[puppetList[i]][trader] = _timeList[i];
        }
    }

    function setFundingActivity(address puppet, address trader, uint _time) external isSetter {
        fundingActivityMap[puppet][trader] = _time;
    }

    function getFundingActivity(address puppet, address trader) external view returns (uint) {
        return fundingActivityMap[puppet][trader];
    }

    function getBalanceAndActivityList(IERC20 collateralToken, address trader, address[] calldata _puppetList)
        external
        view
        returns (Rule[] memory _ruleList, uint[] memory _fundingActivityList, uint[] memory _balanceList)
    {
        uint _puppetListLength = _puppetList.length;

        _ruleList = new Rule[](_puppetListLength);
        _fundingActivityList = new uint[](_puppetListLength);
        _balanceList = new uint[](_puppetListLength);

        for (uint i = 0; i < _puppetListLength; i++) {
            _ruleList[i] = ruleMap[PositionUtils.getRuleKey(collateralToken, _puppetList[i], trader)];
            _fundingActivityList[i] = fundingActivityMap[_puppetList[i]][trader];
            _balanceList[i] = balanceMap[_puppetList[i]][collateralToken];
        }
        return (_ruleList, _fundingActivityList, _balanceList);
    }

    function setBalanceAndActivityList(
        IERC20 collateralToken,
        address trader,
        address[] calldata _puppetList,
        uint[] calldata _activityList,
        uint[] calldata _balanceList
    ) external isSetter {
        uint _puppetListLength = _puppetList.length;

        if (_puppetListLength != _activityList.length || _puppetListLength != _balanceList.length) revert PuppetStore__InvalidLength();

        for (uint i = 0; i < _puppetListLength; i++) {
            address puppet = _puppetList[i];
            fundingActivityMap[puppet][trader] = _activityList[i];
            balanceMap[puppet][collateralToken] = _balanceList[i];
        }
    }

    error PuppetStore__InvalidLength();
}
