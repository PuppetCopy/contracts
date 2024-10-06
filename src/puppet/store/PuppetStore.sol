// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {Error} from "../../shared/Error.sol";
import {Router} from "./../../shared/Router.sol";
import {BankStore} from "./../../shared/store/BankStore.sol";
import {Precision} from "./../../utils/Precision.sol";
import {IAuthority} from "./../../utils/interfaces/IAuthority.sol";

contract PuppetStore is BankStore {
    struct MatchRule {
        uint allowanceRate;
    }

    struct AllocationRule {
        uint throttleActivity;
    }

    struct Allocation {
        bytes32 matchKey;
        IERC20 collateralToken;
        uint allocated;
        uint collateral;
        uint size;
        uint settled;
    }

    uint requestId = 0;
    mapping(IERC20 token => uint) tokenAllowanceCapMap;
    mapping(IERC20 token => mapping(address user => uint)) userBalanceMap;

    mapping(address puppet => uint) activityThrottleMap;
    mapping(address puppet => AllocationRule) allocationRuleMap;

    mapping(bytes32 matchKey => mapping(address puppet => MatchRule)) matchRuleMap;
    mapping(bytes32 listHash => bytes32 allocationKey) settledAllocationHashMap;
    mapping(bytes32 allocationKey => mapping(address puppet => uint amount)) userAllocationMap;
    mapping(bytes32 allocationKey => Allocation) allocationMap;

    constructor(IAuthority _authority, Router _router) BankStore(_authority, _router) {}

    function getSettledAllocationHash(bytes32 _hash) external view returns (bytes32) {
        return settledAllocationHashMap[_hash];
    }

    function setSettledAllocationHash(bytes32 _hash, bytes32 _key) external auth {
        settledAllocationHashMap[_hash] = _key;
    }

    function getAllocationRule(address _puppet) external view returns (AllocationRule memory) {
        return allocationRuleMap[_puppet];
    }

    function setAllocationRule(address _puppet, AllocationRule calldata _rule) external auth {
        if (activityThrottleMap[_puppet] == 0) activityThrottleMap[_puppet] = 1;

        allocationRuleMap[_puppet] = _rule;
    }

    function getRequestId() external view returns (uint) {
        return requestId;
    }

    function incrementRequestId() external auth returns (uint) {
        return requestId += 1;
    }

    function getTokenAllowanceCap(IERC20 _token) external view returns (uint) {
        return tokenAllowanceCapMap[_token];
    }

    function setTokenAllowanceCap(IERC20 _token, uint _value) external auth {
        tokenAllowanceCapMap[_token] = _value;
    }

    function getUserBalance(IERC20 _token, address _account) external view returns (uint) {
        return userBalanceMap[_token][_account];
    }

    function increaseBalance(IERC20 _token, address _depositor, uint _value) external auth returns (uint) {
        transferIn(_token, _depositor, _value);

        return userBalanceMap[_token][_depositor] += _value;
    }

    function getBalanceList(IERC20 _token, address[] calldata _accountList) external view returns (uint[] memory) {
        uint _accountListLength = _accountList.length;
        uint[] memory _balanceList = new uint[](_accountListLength);
        for (uint i = 0; i < _accountListLength; i++) {
            _balanceList[i] = userBalanceMap[_token][_accountList[i]];
        }
        return _balanceList;
    }

    function getUserAllocation(address _puppet, bytes32 _key) external view returns (uint) {
        return userAllocationMap[_key][_puppet];
    }

    function setUserAllocation(bytes32 _key, address _puppet, uint _value) external auth {
        userAllocationMap[_key][_puppet] = _value;
    }

    function getUserAllocationList(
        bytes32 _key,
        address[] calldata _puppetList
    ) external view returns (uint[] memory _allocationList) {
        uint _puppetListLength = _puppetList.length;
        _allocationList = new uint[](_puppetListLength);

        for (uint i = 0; i < _puppetListLength; i++) {
            _allocationList[i] = userAllocationMap[_key][_puppetList[i]];
        }

        return _allocationList;
    }

    function allocate(IERC20 _token, bytes32 _matchKey, address _puppet, uint _allocationAmount) external auth {
        if (userAllocationMap[_matchKey][_puppet] > 0) {
            revert Error.PuppetStore__OverwriteAllocation();
        }

        if (_allocationAmount == 0) return;

        userBalanceMap[_token][_puppet] -= _allocationAmount;
        userAllocationMap[_matchKey][_puppet] = _allocationAmount;
        allocationMap[_matchKey].allocated += _allocationAmount;
        activityThrottleMap[_puppet] = block.timestamp + allocationRuleMap[_puppet].throttleActivity;
    }

    function getAllocation(bytes32 _matchKey, address _puppet) public view auth returns (uint) {
        return userAllocationMap[_matchKey][_puppet];
    }

    function allocatePuppetList(
        IERC20 _token,
        bytes32 _allocationKey,
        address[] calldata _puppetList,
        uint[] calldata _allocationList
    ) external auth returns (uint) {
        mapping(address => uint) storage balance = userBalanceMap[_token];
        mapping(address => uint) storage allocationAmount = userAllocationMap[_allocationKey];
        uint listLength = _puppetList.length;
        uint allocated;

        for (uint i = 0; i < listLength; i++) {
            uint _allocation = _allocationList[i];
            address _puppet = _puppetList[i];

            if (allocationAmount[_puppet] > 0) revert Error.PuppetStore__OverwriteAllocation();
            if (_allocation == 0) continue;

            balance[_puppet] -= _allocation;
            allocationAmount[_puppet] = _allocation;
            activityThrottleMap[_puppet] = block.timestamp + allocationRuleMap[_puppet].throttleActivity;
            allocated += _allocation;
        }

        return allocated;
    }

    function increaseBalanceList(
        IERC20 _token,
        address[] calldata _accountList,
        uint[] calldata _valueList
    ) external auth returns (uint) {
        uint _accountListLength = _accountList.length;
        uint totalAmountIn;

        if (_accountListLength != _valueList.length) revert Error.Store__InvalidLength();

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

    function getMatchRuleList(
        address _puppet,
        bytes32[] calldata _matchKeyList
    ) external view returns (MatchRule[] memory) {
        uint _keyListLength = _matchKeyList.length;
        MatchRule[] memory _ruleList = new MatchRule[](_keyListLength);

        for (uint i = 0; i < _keyListLength; i++) {
            _ruleList[i] = matchRuleMap[_matchKeyList[i]][_puppet];
        }

        return _ruleList;
    }

    function getMatchRule(bytes32 _key, address _puppet) external view returns (MatchRule memory) {
        return matchRuleMap[_key][_puppet];
    }

    function setMatchRule(bytes32 _key, address _puppet, MatchRule calldata _rule) external auth {
        matchRuleMap[_key][_puppet] = _rule;
    }

    function setMatchRuleList(
        address _puppet,
        bytes32[] calldata _matchKeyList,
        MatchRule[] calldata _rules
    ) external auth {
        uint _keyListLength = _matchKeyList.length;
        if (_keyListLength != _rules.length) revert Error.Store__InvalidLength();

        mapping(address => MatchRule) storage matchRule = matchRuleMap[_matchKeyList[0]];

        for (uint i = 0; i < _keyListLength; i++) {
            matchRule[_puppet] = _rules[i];
        }
    }

    function getPuppetRouteRuleList(
        address _puppet,
        bytes32[] calldata _matchKeyList
    ) external view returns (MatchRule[] memory) {
        uint _keyListLength = _matchKeyList.length;
        MatchRule[] memory _ruleList = new MatchRule[](_keyListLength);

        for (uint i = 0; i < _keyListLength; i++) {
            _ruleList[i] = matchRuleMap[_matchKeyList[i]][_puppet];
        }

        return _ruleList;
    }

    function getActivityThrottleList(address[] calldata puppetList) external view returns (uint[] memory) {
        uint _puppetListLength = puppetList.length;
        uint[] memory _activityList = new uint[](_puppetListLength);

        for (uint i = 0; i < _puppetListLength; i++) {
            _activityList[i] = activityThrottleMap[puppetList[i]];
        }

        return _activityList;
    }

    function setActivityThrottle(address puppet, uint _time) external auth {
        activityThrottleMap[puppet] = _time;
    }

    function getActivityThrottle(address puppet) external view returns (uint) {
        return activityThrottleMap[puppet];
    }

    function getBalanceAndActivityThrottle(
        IERC20 _token,
        bytes32 _matchKey,
        address _puppet
    ) external view returns (uint _rate, uint _allocationActivity, uint _balance) {
        return (
            matchRuleMap[_matchKey][_puppet].allowanceRate,
            activityThrottleMap[_puppet],
            userBalanceMap[_token][_puppet]
        );
    }

    function getBalanceAndActivityThrottleList(
        IERC20 _token,
        bytes32 _matchKey,
        address[] calldata _puppetList
    ) external view returns (uint[] memory _rateList, uint[] memory _activityList, uint[] memory _balanceList) {
        uint _puppetListLength = _puppetList.length;

        _rateList = new uint[](_puppetListLength);
        _activityList = new uint[](_puppetListLength);
        _balanceList = new uint[](_puppetListLength);

        mapping(address => MatchRule) storage matchRule = matchRuleMap[_matchKey];

        for (uint i = 0; i < _puppetListLength; i++) {
            address _puppet = _puppetList[i];
            _rateList[i] = matchRule[_puppet].allowanceRate;
            _activityList[i] = activityThrottleMap[_puppet];
            _balanceList[i] = userBalanceMap[_token][_puppet];
        }
        return (_rateList, _activityList, _balanceList);
    }

    function getAllocation(bytes32 _key) external view returns (Allocation memory) {
        return allocationMap[_key];
    }

    function setAllocation(bytes32 _key, Allocation calldata _settlement) external auth {
        allocationMap[_key] = _settlement;
    }

    function removeAllocation(bytes32 _key) external auth {
        delete allocationMap[_key];
    }

    function settle(IERC20 _token, address _puppet, uint _settleAmount) external auth {
        userBalanceMap[_token][_puppet] += _settleAmount;
    }

    function settleList(
        IERC20 _token,
        address[] calldata _puppetList,
        uint[] calldata _settleAmountList
    ) external auth {
        mapping(address => uint) storage tokenBalanceMap = userBalanceMap[_token];

        uint _puppetListLength = _puppetList.length;
        for (uint i = 0; i < _puppetListLength; i++) {
            tokenBalanceMap[_puppetList[i]] += _settleAmountList[i];
        }
    }
}
