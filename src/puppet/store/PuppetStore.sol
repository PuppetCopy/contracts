// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {Error} from "../../shared/Error.sol";
import {Router} from "./../../shared/Router.sol";
import {BankStore} from "./../../shared/store/BankStore.sol";
import {Precision} from "./../../utils/Precision.sol";
import {Auth} from "./../../utils/access/Auth.sol";
import {IAuthority} from "./../../utils/interfaces/IAuthority.sol";

contract PuppetStore is BankStore {
    struct RouteAllocationRule {
        uint throttleActivity;
        uint allowanceRate;
        uint expiry;
    }

    struct RouteAllocation {
        address puppet;
        uint amount;
    }

    struct IndexedMatchedAllocationList {
        RouteAllocation[] list;
        mapping(address value => uint) indexMap;
    }

    struct AllocationMatch {
        IERC20 token;
        uint allocatedCount;
        uint totalAllocated;
        uint amountOut;
        uint atIndex;
    }

    struct Settlement {
        uint amountIn;
        uint profit;
        uint atIndex;
        bytes32 routeKey;
    }

    mapping(IERC20 token => uint) tokenAllowanceCapMap;

    mapping(bytes32 => mapping(address => RouteAllocationRule)) routeAllocationRuleMap;
    mapping(bytes32 => IndexedMatchedAllocationList) routeIndexedMatchedAllocationListMap;
    mapping(bytes32 => AllocationMatch) allocationMatchMap;
    mapping(bytes32 => Settlement) settlementMap;

    mapping(IERC20 token => mapping(address user => uint)) userBalanceMap;
    mapping(bytes32 routeKey => mapping(address puppet => uint)) allocationActivityMap;

    constructor(IAuthority _authority, Router _router) BankStore(_authority, _router) {}

    function getTokenAllowanceCap(IERC20 _token) external view returns (uint) {
        return tokenAllowanceCapMap[_token];
    }

    function setTokenAllowanceCap(IERC20 _token, uint _value) external auth {
        tokenAllowanceCapMap[_token] = _value;
    }

    function allocateList(
        IERC20 _token,
        bytes32 _routeKey,
        uint _fromIndex,
        uint _toIndex
    ) external auth returns (uint totalAllocated, RouteAllocation[] memory _matchedAllocations) {
        AllocationMatch storage allocationMatch = allocationMatchMap[_routeKey];
        uint setLength = routeIndexedMatchedAllocationListMap[_routeKey].list.length;

        allocationMatch.token = _token;
        (totalAllocated, _matchedAllocations) =
            _processAllocations(_token, _routeKey, _fromIndex, Math.min(_toIndex, setLength));
        allocationMatch.atIndex = _matchedAllocations.length;
        allocationMatch.totalAllocated = totalAllocated;
    }

    function _processAllocations(
        IERC20 _token,
        bytes32 _routeKey,
        uint _fromIndex,
        uint _toIndex
    ) internal returns (uint totalAllocated, RouteAllocation[] memory _matchedAllocations) {
        IndexedMatchedAllocationList storage indexedList = routeIndexedMatchedAllocationListMap[_routeKey];

        _matchedAllocations = new RouteAllocation[](_toIndex - _fromIndex);

        for (uint i = _fromIndex; i < _toIndex; i++) {
            RouteAllocation storage allocation = indexedList.list[i];
            address puppet = allocation.puppet;
            RouteAllocationRule storage rule = routeAllocationRuleMap[_routeKey][puppet];

            if (rule.expiry < block.timestamp) {
                // delete an element by swapping the last element with the current element
                RouteAllocation memory lastValue = indexedList.list[indexedList.list.length - 1];

                indexedList.list[i] = lastValue;
                indexedList.indexMap[lastValue.puppet] = i + 1;

                indexedList.list.pop();
                delete indexedList.indexMap[puppet];
                delete routeAllocationRuleMap[_routeKey][puppet];

                // decrement the index to avoid skipping swapped element
                i--;
                continue;
            }

            if (allocationActivityMap[_routeKey][puppet] + rule.throttleActivity > block.timestamp) {
                allocation.amount = 0;
                continue;
            }

            allocationActivityMap[_routeKey][puppet] = block.timestamp;
            allocation.amount = Precision.applyBasisPoints(rule.allowanceRate, userBalanceMap[_token][puppet]);
            totalAllocated += allocation.amount;
            _matchedAllocations[i] = allocation;
        }
    }

    function transferOutAllocation(
        IERC20 _token,
        bytes32 _routeKey,
        address _receiver,
        uint _amountOut
    ) external auth {
        AllocationMatch storage allocationMatch = allocationMatchMap[_routeKey];
        if (allocationMatch.amountOut > 0) revert Error.PuppetStore__TransferredOutAlready();
        if (allocationMatch.totalAllocated == 0) revert Error.PuppetStore__ZeroAllocation();

        allocationMatch.amountOut = _amountOut;
        transferOut(_token, _receiver, _amountOut);
    }

    function getAllocationMatch(bytes32 _routeKey) external view returns (AllocationMatch memory) {
        return allocationMatchMap[_routeKey];
    }

    function removeAllocationMatch(bytes32 _routeKey) external auth {
        delete allocationMatchMap[_routeKey];
    }

    function settleRound(
        IERC20 _token,
        bytes32 _routeKey,
        address[] calldata _puppetList,
        uint[] calldata _amountList
    ) external auth {
        uint _puppetListLength = _puppetList.length;

        if (_puppetListLength != _amountList.length) revert Error.PuppetStore__InvalidLength();

        for (uint i = 0; i < _puppetListLength; i++) {
            address _puppet = _puppetList[i];
            uint _amount = _amountList[i];
            userBalanceMap[_token][_puppet] += _amount;
            allocationActivityMap[_routeKey][_puppet] = block.timestamp;
        }
    }

    function getUserBalance(IERC20 _token, address _account) external view returns (uint) {
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

    function getAllocationRule(bytes32 _routeKey, address puppet) external view returns (RouteAllocationRule memory) {
        return routeAllocationRuleMap[_routeKey][puppet];
    }

    function getRouteAllocationRuleList(
        address _puppet,
        bytes32[] calldata _routeKeyList
    ) external view returns (RouteAllocationRule[] memory) {
        uint _keyListLength = _routeKeyList.length;
        RouteAllocationRule[] memory _ruleList = new RouteAllocationRule[](_keyListLength);

        for (uint i = 0; i < _keyListLength; i++) {
            _ruleList[i] = routeAllocationRuleMap[_routeKeyList[i]][_puppet];
        }

        return _ruleList;
    }

    function setRouteAllocationRule(
        bytes32 _routeKey,
        address puppet,
        RouteAllocationRule calldata _rule
    ) public auth returns (uint index) {
        IndexedMatchedAllocationList storage indexedList = routeIndexedMatchedAllocationListMap[_routeKey];

        index = indexedList.indexMap[puppet];

        if (index == 0) {
            indexedList.list.push(RouteAllocation(puppet, 0));
            indexedList.indexMap[puppet] = routeIndexedMatchedAllocationListMap[_routeKey].list.length;
        }

        routeAllocationRuleMap[_routeKey][puppet] = _rule;
    }

    function getRouteAllocationList(bytes32 _routeKey) external view returns (RouteAllocation[] memory) {
        return routeIndexedMatchedAllocationListMap[_routeKey].list;
    }

    function setRouteAllocationRuleList(
        address _puppet,
        bytes32[] calldata _routeKeyList,
        RouteAllocationRule[] calldata _rules
    ) external auth returns (uint[] memory _indexList) {
        uint _keyListLength = _routeKeyList.length;
        _indexList = new uint[](_keyListLength);

        for (uint i = 0; i < _keyListLength; i++) {
            _indexList[i] = setRouteAllocationRule(_routeKeyList[i], _puppet, _rules[i]);
        }
    }

    function getPuppetAllocationRuleList(
        address _puppet,
        bytes32[] calldata _routeKeyList
    ) external view returns (RouteAllocationRule[] memory) {
        uint _keyListLength = _routeKeyList.length;
        RouteAllocationRule[] memory _ruleList = new RouteAllocationRule[](_keyListLength);

        for (uint i = 0; i < _keyListLength; i++) {
            _ruleList[i] = routeAllocationRuleMap[_routeKeyList[i]][_puppet];
        }

        return _ruleList;
    }

    function getAllocationActivityList(
        bytes32 _routeKey,
        address[] calldata puppetList
    ) external view returns (uint[] memory) {
        uint _puppetListLength = puppetList.length;
        uint[] memory _activityList = new uint[](_puppetListLength);

        for (uint i = 0; i < _puppetListLength; i++) {
            _activityList[i] = allocationActivityMap[_routeKey][puppetList[i]];
        }

        return _activityList;
    }

    function setAllocationActivity(bytes32 _routeKey, address puppet, uint _time) external auth {
        allocationActivityMap[_routeKey][puppet] = _time;
    }

    function getAllocationActivity(bytes32 _routeKey, address puppet) external view returns (uint) {
        return allocationActivityMap[_routeKey][puppet];
    }

    function getBalanceAndActivityList(
        IERC20 _token,
        bytes32 _routeKey,
        address[] calldata _puppetList
    )
        external
        view
        returns (
            RouteAllocationRule[] memory _ruleList,
            uint[] memory _allocationActivityList,
            uint[] memory _valueList
        )
    {
        uint _puppetListLength = _puppetList.length;

        _ruleList = new RouteAllocationRule[](_puppetListLength);
        _allocationActivityList = new uint[](_puppetListLength);
        _valueList = new uint[](_puppetListLength);

        for (uint i = 0; i < _puppetListLength; i++) {
            address _puppet = _puppetList[i];
            _ruleList[i] = routeAllocationRuleMap[_routeKey][_puppet];
            _allocationActivityList[i] = allocationActivityMap[_routeKey][_puppet];
            _valueList[i] = userBalanceMap[_token][_puppet];
        }
        return (_ruleList, _allocationActivityList, _valueList);
    }

    function getAllocationMatchList(bytes32 _routeKey) external view returns (AllocationMatch memory) {
        return allocationMatchMap[_routeKey];
    }

    function setAllocationMatch(bytes32 _routeKey, AllocationMatch calldata _allocationMatch) external auth {
        allocationMatchMap[_routeKey] = _allocationMatch;
    }

    function setSettlement(bytes32 _routeKey, uint _amountIn, uint _profit) external auth {
        settlementMap[_routeKey] = Settlement({amountIn: _amountIn, atIndex: 0, profit: _profit, routeKey: _routeKey});
    }

    function getSettlement(bytes32 _routeKey) external view returns (Settlement memory) {
        return settlementMap[_routeKey];
    }

    function settleList(
        IERC20 _token,
        bytes32 _routeKey,
        uint _fromIndex,
        uint _toIndex,
        uint _settlementAmountInAfterFee
    ) external auth returns (address[] memory _puppetContributionList, uint[] memory _puppetContributionAmountList) {
        Settlement storage settlement = settlementMap[_routeKey];
        IndexedMatchedAllocationList storage indexedList = routeIndexedMatchedAllocationListMap[_routeKey];

        _puppetContributionList = new address[](_toIndex - _fromIndex);
        _puppetContributionAmountList = new uint[](_toIndex - _fromIndex);

        for (uint i = _fromIndex; i < _toIndex; i++) {
            RouteAllocation memory allocation = indexedList.list[i];
            uint amountIn = allocation.amount * _settlementAmountInAfterFee / settlement.amountIn;
            userBalanceMap[_token][allocation.puppet] += amountIn;
            _puppetContributionList[i] = allocation.puppet;
            _puppetContributionAmountList[i] = amountIn;
        }

        settlement.atIndex = _puppetContributionList.length;
        delete allocationMatchMap[_routeKey];
    }
}
