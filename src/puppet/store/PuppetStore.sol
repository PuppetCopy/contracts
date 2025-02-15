// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {Error} from "../../shared/Error.sol";
import {TokenRouter} from "./../../shared/TokenRouter.sol";
import {BankStore} from "./../../shared/store/BankStore.sol";
import {Precision} from "./../../utils/Precision.sol";
import {IAuthority} from "./../../utils/interfaces/IAuthority.sol";

contract PuppetStore is BankStore {
    struct MatchRule {
        uint allowanceRate;
        uint throttleActivity;
        uint expiry;
    }

    struct Allocation {
        bytes32 matchKey;
        IERC20 collateralToken;
        uint allocated;
        uint collateral;
        uint size;
        uint settled;
        uint profit;
    }

    mapping(IERC20 token => uint) tokenAllowanceCapMap;
    mapping(IERC20 token => mapping(address user => uint)) userBalanceMap;
    uint requestId = 0;

    mapping(bytes32 matchKey => mapping(address puppet => uint)) activityThrottleMap;
    mapping(bytes32 matchKey => mapping(address puppet => MatchRule)) matchRuleMap;
    mapping(bytes32 listHash => bytes32 allocationKey) settledAllocationHashMap;
    mapping(bytes32 allocationKey => mapping(address puppet => uint amount)) userAllocationMap;
    mapping(bytes32 allocationKey => Allocation) allocationMap;

    constructor(IAuthority _authority, TokenRouter _router) BankStore(_authority, _router) {}

    function getSettledAllocationHash(
        bytes32 _hash
    ) external view returns (bytes32) {
        return settledAllocationHashMap[_hash];
    }

    function setSettledAllocationHash(bytes32 _hash, bytes32 _key) external auth {
        settledAllocationHashMap[_hash] = _key;
    }

    function getTokenAllowanceCap(
        IERC20 _token
    ) external view returns (uint) {
        return tokenAllowanceCapMap[_token];
    }

    function setTokenAllowanceCap(IERC20 _token, uint _value) external auth {
        tokenAllowanceCapMap[_token] = _value;
    }

    function getUserBalance(IERC20 _token, address _account) external view returns (uint) {
        return userBalanceMap[_token][_account];
    }

    function getBalanceList(IERC20 _token, address[] calldata _userList) external view returns (uint[] memory) {
        uint _accountListLength = _userList.length;
        uint[] memory _balanceList = new uint[](_accountListLength);
        for (uint i = 0; i < _accountListLength; i++) {
            _balanceList[i] = userBalanceMap[_token][_userList[i]];
        }
        return _balanceList;
    }

    function getBalanceAndAllocationList(
        IERC20 _token,
        bytes32 _key,
        address[] calldata _puppetList
    ) external view returns (uint[] memory _balanceList, uint[] memory _allocationList) {
        uint _puppetListLength = _puppetList.length;
        _balanceList = new uint[](_puppetListLength);
        _allocationList = new uint[](_puppetListLength);

        for (uint i = 0; i < _puppetListLength; i++) {
            address _puppet = _puppetList[i];
            _balanceList[i] = userBalanceMap[_token][_puppet];
            _allocationList[i] = userAllocationMap[_key][_puppet];
        }

        return (_balanceList, _allocationList);
    }

    function setBalanceList(
        IERC20 _token,
        address[] calldata _accountList,
        uint[] calldata _balanceList
    ) external auth {
        uint _accountListLength = _accountList.length;
        for (uint i = 0; i < _accountListLength; i++) {
            userBalanceMap[_token][_accountList[i]] = _balanceList[i];
        }
    }

    function getRequestId() external view returns (uint) {
        return requestId;
    }

    function incrementRequestId() external auth returns (uint) {
        return requestId += 1;
    }

    function getUserAllocation(bytes32 _key, address _puppet) external view returns (uint) {
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

    function allocate(
        IERC20 _token,
        bytes32 _matchKey,
        bytes32 _allocationKey,
        address _puppet,
        uint _allocationAmount
    ) external auth {
        require(userAllocationMap[_allocationKey][_puppet] == 0, Error.PuppetStore__OverwriteAllocation());

        if (_allocationAmount == 0) return;

        userBalanceMap[_token][_puppet] -= _allocationAmount;
        userAllocationMap[_allocationKey][_puppet] = _allocationAmount;
        allocationMap[_allocationKey].allocated += _allocationAmount;
        activityThrottleMap[_matchKey][_puppet] = block.timestamp + matchRuleMap[_matchKey][_puppet].throttleActivity;
    }

    function getAllocation(bytes32 _matchKey, address _puppet) public view auth returns (uint) {
        return userAllocationMap[_matchKey][_puppet];
    }

    function allocatePuppetList(
        IERC20 _token,
        bytes32 _matchKey,
        bytes32 _allocationKey,
        address[] calldata _puppetList,
        uint[] calldata _allocationList
    ) external auth returns (uint) {
        mapping(address => uint) storage balance = userBalanceMap[_token];
        mapping(address => uint) storage allocationAmount = userAllocationMap[_allocationKey];
        uint listLength = _puppetList.length;
        uint allocated;

        for (uint i = 0; i < listLength; i++) {
            address _puppet = _puppetList[i];
            require(allocationAmount[_puppet] == 0, Error.PuppetStore__OverwriteAllocation());

            uint _allocation = _allocationList[i];

            if (_allocation == 0) continue;

            balance[_puppet] -= _allocation;
            allocationAmount[_puppet] = _allocation;
            activityThrottleMap[_matchKey][_puppet] =
                block.timestamp + matchRuleMap[_matchKey][_puppet].throttleActivity;
            allocated += _allocation;
        }

        return allocated;
    }

    function setBalance(IERC20 _token, address _user, uint _value) public auth returns (uint) {
        return userBalanceMap[_token][_user] = _value;
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

        // pre-store to save gas during inital allocation or-and reset throttle activity
        if (activityThrottleMap[_key][_puppet] == 0) {
            activityThrottleMap[_key][_puppet] = 1;
        }
    }

    function setMatchRuleList(
        address _puppet,
        bytes32[] calldata _matchKeyList,
        MatchRule[] calldata _rules
    ) external auth {
        uint _keyListLength = _matchKeyList.length;
        require(_keyListLength == _rules.length, Error.Store__InvalidLength());

        for (uint i = 0; i < _keyListLength; i++) {
            bytes32 _key = _matchKeyList[i];
            matchRuleMap[_key][_puppet] = _rules[i];
            // pre-store to save gas during inital allocation or-and reset throttle activity
            if (activityThrottleMap[_key][_puppet] == 0) {
                activityThrottleMap[_key][_puppet] = 1;
            }
        }
    }

    function getPuppetMatchRuleList(
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

    function getActivityThrottleList(
        bytes32 _key,
        address[] calldata puppetList
    ) external view returns (uint[] memory) {
        uint _puppetListLength = puppetList.length;
        uint[] memory _activityList = new uint[](_puppetListLength);

        for (uint i = 0; i < _puppetListLength; i++) {
            _activityList[i] = activityThrottleMap[_key][puppetList[i]];
        }

        return _activityList;
    }

    function setActivityThrottle(address _puppet, bytes32 _key, uint _time) external auth {
        activityThrottleMap[_key][_puppet] = _time;
    }

    function getActivityThrottle(address _puppet, bytes32 _key) external view returns (uint) {
        return activityThrottleMap[_key][_puppet];
    }

    function getBalanceAndActivityThrottle(
        IERC20 _token,
        bytes32 _matchKey,
        address _puppet
    ) external view returns (MatchRule memory _rule, uint _allocationActivity, uint _balance) {
        return
            (matchRuleMap[_matchKey][_puppet], activityThrottleMap[_matchKey][_puppet], userBalanceMap[_token][_puppet]);
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
            _activityList[i] = activityThrottleMap[_matchKey][_puppet];
            _balanceList[i] = userBalanceMap[_token][_puppet];
        }
        return (_ruleList, _activityList, _balanceList);
    }

    function getAllocation(
        bytes32 _key
    ) external view returns (Allocation memory) {
        return allocationMap[_key];
    }

    function setAllocation(bytes32 _key, Allocation calldata _settlement) external auth {
        allocationMap[_key] = _settlement;
    }

    function removeAllocation(
        bytes32 _key
    ) external auth {
        delete allocationMap[_key];
    }

    function settle(IERC20 _token, address _puppet, uint _settleAmount) external auth {
        userBalanceMap[_token][_puppet] += _settleAmount;
    }
}
