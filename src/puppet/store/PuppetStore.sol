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

    struct TradeRoute {
        uint allowanceRate;
        uint balance;
    }

    struct AllocationRule {
        uint throttleActivity;
        uint concurrentPositionLimit;
    }

    struct Allocation {
        IERC20 token;
        uint allocated;
        uint amountOut;
        uint size;
        bytes32[] matchHashList;
    }

    struct Settlement {
        bytes32 matchKey;
        uint settled;
    }

    uint requestId = 0;
    mapping(IERC20 token => uint) tokenAllowanceCapMap;
    mapping(IERC20 token => mapping(address user => uint)) userBalanceMap;

    mapping(address puppet => uint) activityThrottleMap;
    mapping(address puppet => AllocationRule) allocationRuleMap;

    mapping(bytes32 matchKey => mapping(address puppet => MatchRule)) matchRuleMap;
    mapping(bytes32 matchKey => mapping(address puppet => uint amount)) userAllocationMap;
    mapping(bytes32 matchKey => Allocation) slotAllocationMap;
    mapping(bytes32 settlementKey => Settlement) settlementMap;

    constructor(IAuthority _authority, Router _router) BankStore(_authority, _router) {}

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

    // function getUserBalance(IERC20 _token, address _account) external view returns (uint) {
    //     return userBalanceMap[_token][_account];
    // }

    // function increaseBalance(IERC20 _token, address _depositor, uint _value) external auth returns (uint) {
    //     transferIn(_token, _depositor, _value);

    //     return userBalanceMap[_token][_depositor] += _value;
    // }

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

    function getAllocationList(
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

    function allocate(
        IERC20 _token,
        bytes32 _matchKey,
        address _puppet,
        uint _allocationAmount
    ) external auth returns (uint) {
        userBalanceMap[_token][_puppet] -= _allocationAmount;
        userAllocationMap[_matchKey][_puppet] = _allocationAmount;
        slotAllocationMap[_matchKey].allocated += _allocationAmount;
        activityThrottleMap[_puppet] = block.timestamp + allocationRuleMap[_puppet].throttleActivity;

        return _allocationAmount;
    }

    function getAllocation(bytes32 _matchKey, address _puppet) public view auth returns (uint) {
        return userAllocationMap[_matchKey][_puppet];
    }

    function allocatePuppetList(
        IERC20 _token,
        bytes32 _matchKey,
        address[] calldata _puppetList,
        uint[] calldata _amountList
    ) external auth returns (uint) {
        mapping(address => uint) storage balance = userBalanceMap[_token];
        mapping(address => uint) storage allocationAmount = userAllocationMap[_matchKey];
        uint listLength = _puppetList.length;
        uint totalAllocated;

        for (uint i = 0; i < listLength; i++) {
            uint _allocation = _amountList[i];

            if (_allocation <= 1) continue;

            address _puppet = _puppetList[i];

            balance[_puppet] -= _allocation;
            allocationAmount[_puppet] += _allocation;
            activityThrottleMap[_puppet] = block.timestamp + allocationRuleMap[_puppet].throttleActivity;
            totalAllocated += _allocation;
        }

        slotAllocationMap[_matchKey].allocated += totalAllocated;
        slotAllocationMap[_matchKey].matchHashList.push(keccak256(abi.encode(_puppetList)));

        return totalAllocated;
    }

    function transferOutAllocation(
        IERC20 _token,
        bytes32 _allocationKey,
        address _receiver,
        uint _amountOut
    ) external auth {
        Allocation storage allocation = slotAllocationMap[_allocationKey];

        transferOut(_token, _receiver, _amountOut);
        allocation.amountOut = _amountOut;
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

    function getMatchRule(bytes32 _matchKey, address _puppet) external view returns (MatchRule memory) {
        return matchRuleMap[_matchKey][_puppet];
    }

    function setMatchRule(bytes32 _matchKey, address _puppet, MatchRule calldata _rule) external auth {
        mapping(address => uint) storage amountMap = userAllocationMap[_matchKey];

        // Initialize allocation amount to 1 to pre-allocate storage slot
        if (amountMap[_puppet] == 0) {
            amountMap[_puppet] = 1;
        }

        matchRuleMap[_matchKey][_puppet] = _rule;
    }

    function setRouteRuleList(
        address _puppet,
        bytes32[] calldata _matchKeyList,
        MatchRule[] calldata _rules
    ) external auth {
        uint _keyListLength = _matchKeyList.length;
        if (_keyListLength != _rules.length) revert Error.Store__InvalidLength();

        for (uint i = 0; i < _keyListLength; i++) {
            bytes32 _key = _matchKeyList[i];

            mapping(address => uint) storage amountMap = userAllocationMap[_key];

            // Initialize allocation amount to 1 to pre-allocate storage slot
            if (amountMap[_puppet] == 0) {
                amountMap[_puppet] = 1;
            }

            matchRuleMap[_key][_puppet] = _rules[i];
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
    ) external view returns (MatchRule memory _rule, uint _allocationActivity, uint _balance) {
        return (matchRuleMap[_matchKey][_puppet], activityThrottleMap[_puppet], userBalanceMap[_token][_puppet]);
    }

    function getBalanceAndActivityThrottleList(
        IERC20 _token,
        bytes32 _matchKey,
        address[] calldata _puppetList
    ) external view returns (MatchRule[] memory _ruleList, uint[] memory _activityList, uint[] memory _balanceList) {
        uint _puppetListLength = _puppetList.length;

        _ruleList = new MatchRule[](_puppetListLength);
        _activityList = new uint[](_puppetListLength);
        _balanceList = new uint[](_puppetListLength);

        mapping(address => MatchRule) storage matchRule = matchRuleMap[_matchKey];

        for (uint i = 0; i < _puppetListLength; i++) {
            address _puppet = _puppetList[i];
            _ruleList[i] = matchRule[_puppet];
            _activityList[i] = activityThrottleMap[_puppet];
            _balanceList[i] = userBalanceMap[_token][_puppet];
        }
        return (_ruleList, _activityList, _balanceList);
    }

    function getAllocation(bytes32 _matchKey) external view returns (Allocation memory) {
        return slotAllocationMap[_matchKey];
    }

    function setAllocation(bytes32 _matchKey, Allocation calldata _settlement) external auth {
        slotAllocationMap[_matchKey] = _settlement;
    }

    function removeAllocation(bytes32 _matchKey) external auth {
        delete slotAllocationMap[_matchKey];
    }

    function getSettlement(bytes32 _settlementKey) external view returns (Settlement memory) {
        return settlementMap[_settlementKey];
    }

    function setSettlement(bytes32 _settlementKey, Settlement calldata _settlement) external auth {
        settlementMap[_settlementKey] = _settlement;
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

    function removeSettlement(bytes32 _matchKey) external auth {
        delete settlementMap[_matchKey];
    }
}
