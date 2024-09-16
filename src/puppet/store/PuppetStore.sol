// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {PositionUtils} from "../../position/utils/PositionUtils.sol";
import {Error} from "../../shared/Error.sol";
import {Router} from "./../../shared/Router.sol";
import {BankStore} from "./../../shared/store/BankStore.sol";
import {Auth} from "./../../utils/access/Auth.sol";
import {IAuthority} from "./../../utils/interfaces/IAuthority.sol";

contract PuppetStore is BankStore {
    struct AllocationRule {
        uint throttleActivity;
        uint allowanceRate;
        uint expiry;
    }

    mapping(IERC20 token => uint) public tokenAllowanceCapMap;
    mapping(IERC20 token => mapping(address user => uint) name) userBalanceMap;
    mapping(bytes32 ruleKey => AllocationRule) public allocationRuleMap;
    mapping(address trader => mapping(address user => uint) name) public fundingActivityMap;

    constructor(IAuthority _authority, Router _router) BankStore(_authority, _router) {}

    function getTokenAllowanceCap(IERC20 _token) external view returns (uint) {
        return tokenAllowanceCapMap[_token];
    }

    function setTokenAllowanceCap(IERC20 _token, uint _value) external auth {
        tokenAllowanceCapMap[_token] = _value;
    }

    function getBalance(IERC20 _token, address _account) external view returns (uint) {
        return userBalanceMap[_token][_account];
    }

    function getBalanceList(IERC20 _token, address[] calldata _accountList) external view returns (uint[] memory) {
        uint _accountListLength = _accountList.length;
        uint[] memory _balanceList = new uint[](_accountListLength);
        for (uint i = 0; i < _accountListLength; i++) {
            _balanceList[i] = userBalanceMap[_token][_accountList[i]];
        }
        return _balanceList;
    }

    function increaseBalance(IERC20 _token, address _depositor, uint _value) external auth returns (uint) {
        transferIn(_token, _depositor, _value);

        return userBalanceMap[_token][_depositor] += _value;
    }

    function increaseBalanceList(
        IERC20 _token,
        address[] calldata _accountList,
        uint[] calldata _valueList
    ) external auth returns (uint) {
        uint _accountListLength = _accountList.length;
        uint totalAmountIn;

        if (_accountListLength != _valueList.length) revert Error.PuppetStore__InvalidLength();

        for (uint i = 0; i < _accountListLength; i++) {
            userBalanceMap[_token][_accountList[i]] += _valueList[i];
            totalAmountIn += _valueList[i];
        }

        return totalAmountIn;
    }

    function decreaseBalance(IERC20 _token, address _user, address _receiver, uint _value) public auth returns (uint) {
        transferOut(_token, _receiver, _value);

        return userBalanceMap[_token][_user] -= _value;
    }

    function getAllocationRule(bytes32 _key) external view returns (AllocationRule memory) {
        return allocationRuleMap[_key];
    }

    function setAllocationRule(bytes32 _key, AllocationRule calldata _rule) external auth {
        allocationRuleMap[_key] = _rule;
    }

    function decreaseBalanceList(
        IERC20 _token,
        address _receiver,
        address[] calldata _accountList,
        uint[] calldata _valueList
    ) external auth {
        uint _accountListLength = _accountList.length;
        uint totalAmountOut;

        if (_accountListLength != _valueList.length) revert Error.PuppetStore__InvalidLength();

        for (uint i = 0; i < _accountListLength; i++) {
            userBalanceMap[_token][_accountList[i]] -= _valueList[i];
            totalAmountOut -= _valueList[i];
        }

        transferOut(_token, _receiver, totalAmountOut);
    }

    function getRuleList(bytes32[] calldata _keyList) external view returns (AllocationRule[] memory) {
        uint _keyListLength = _keyList.length;
        AllocationRule[] memory _rules = new AllocationRule[](_keyList.length);
        for (uint i = 0; i < _keyListLength; i++) {
            _rules[i] = allocationRuleMap[_keyList[i]];
        }
        return _rules;
    }

    function setRuleList(bytes32[] calldata _keyList, AllocationRule[] calldata _rules) external auth {
        uint _keyListLength = _keyList.length;
        uint _ruleLength = _rules.length;

        if (_keyListLength != _ruleLength) revert Error.PuppetStore__InvalidLength();

        for (uint i = 0; i < _keyListLength; i++) {
            allocationRuleMap[_keyList[i]] = _rules[i];
        }
    }

    function getFundingActivityList(
        address trader,
        address[] calldata puppetList
    ) external view returns (uint[] memory) {
        uint _puppetListLength = puppetList.length;
        uint[] memory fundingActivityList = new uint[](_puppetListLength);
        for (uint i = 0; i < _puppetListLength; i++) {
            fundingActivityList[i] = fundingActivityMap[trader][puppetList[i]];
        }
        return fundingActivityList;
    }

    function setFundingActivityList(
        address trader,
        address[] calldata puppetList,
        uint[] calldata _timeList
    ) external auth {
        uint _puppetListLength = puppetList.length;

        if (_puppetListLength != _timeList.length) revert Error.PuppetStore__InvalidLength();

        for (uint i = 0; i < _puppetListLength; i++) {
            fundingActivityMap[trader][puppetList[i]] = _timeList[i];
        }
    }

    function setFundingActivity(address puppet, address trader, uint _time) external auth {
        fundingActivityMap[trader][puppet] = _time;
    }

    function getFundingActivity(address puppet, address trader) external view returns (uint) {
        return fundingActivityMap[trader][puppet];
    }

    function getBalanceAndActivityList(
        IERC20 collateralToken,
        address trader,
        address[] calldata _puppetList
    )
        external
        view
        returns (AllocationRule[] memory _ruleList, uint[] memory _fundingActivityList, uint[] memory _valueList)
    {
        uint _puppetListLength = _puppetList.length;

        _ruleList = new AllocationRule[](_puppetListLength);
        _fundingActivityList = new uint[](_puppetListLength);
        _valueList = new uint[](_puppetListLength);

        for (uint i = 0; i < _puppetListLength; i++) {
            _ruleList[i] = allocationRuleMap[PositionUtils.getRuleKey(collateralToken, _puppetList[i], trader)];
            _fundingActivityList[i] = fundingActivityMap[trader][_puppetList[i]];
            _valueList[i] = userBalanceMap[collateralToken][_puppetList[i]];
        }
        return (_ruleList, _fundingActivityList, _valueList);
    }

    function transferOutAndUpdateActivityList(
        IERC20 _token,
        address _receiver,
        address _trader,
        uint _activityTime,
        address[] calldata _puppetList,
        uint[] calldata _valueList
    ) external auth {
        uint _puppetListLength = _puppetList.length;
        uint totalAmountOut;

        if (_puppetListLength != _valueList.length) revert Error.PuppetStore__InvalidLength();

        for (uint i = 0; i < _puppetListLength; i++) {
            uint _amount = _valueList[i];

            if (_amount == 0) continue;

            address _puppet = _puppetList[i];
            fundingActivityMap[_trader][_puppet] = _activityTime;
            userBalanceMap[_token][_puppet] -= _amount;
            totalAmountOut += _amount;
        }

        transferOut(_token, _receiver, totalAmountOut);
    }
}
