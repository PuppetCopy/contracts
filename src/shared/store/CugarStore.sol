// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {BankStore} from "./../../utils/BankStore.sol";
import {Router} from "./../../utils/Router.sol";

contract CugarStore is BankStore {
    mapping(IERC20 => mapping(uint cursorTime => uint)) cursorBalanceMap;
    mapping(IERC20 => mapping(address => uint)) seedContributionMap;
    mapping(IERC20 => mapping(address => uint)) public userTokenCursorMap;

    constructor(Authority _authority, Router _router, address _initSetter) BankStore(_authority, _router, _initSetter) {}

    function increaseSeedContributionList(
        IERC20 _token, //
        uint _cursor,
        address _depositor,
        address[] calldata _userList,
        uint[] calldata _valueList
    ) external isSetter {
        uint _valueListLength = _valueList.length;
        uint _totalAmount = 0;

        if (_valueListLength != _valueList.length) revert CugarStore__InvalidLength();

        for (uint i = 0; i < _valueListLength; i++) {
            seedContributionMap[_token][_userList[i]] += _valueList[i];
            _totalAmount += _valueList[i];
        }

        cursorBalanceMap[_token][_cursor] += _totalAmount;
        transferIn(_token, _depositor, _totalAmount);
    }

    function increaseSeedContribution(IERC20 _token, uint _cursor, address _depositor, address _user, uint _value) external isSetter {
        seedContributionMap[_token][_user] += _value;
        cursorBalanceMap[_token][_cursor] += _value;
        transferIn(_token, _depositor, _value);
    }

    function setSeedContribution(IERC20 _token, address _user, uint _value) external isSetter {
        seedContributionMap[_token][_user] = _value;
    }

    function getSeedContribution(IERC20 _token, address _user) external view returns (uint) {
        return seedContributionMap[_token][_user];
    }

    function getCursorBalance(IERC20 _token, uint _cursor) external view returns (uint) {
        return cursorBalanceMap[_token][_cursor];
    }

    function decreaseCursorBalance(IERC20 _token, uint _cursor, address _receiver, uint _value) external isSetter {
        cursorBalanceMap[_token][_cursor] -= _value;
        transferOut(_token, _receiver, _value);
    }

    function getSeedContributionList(
        IERC20 _token, //
        address[] calldata _userList
    ) external view returns (uint _totalAmount, uint[] memory _valueList) {
        uint _userListLength = _userList.length;

        _valueList = new uint[](_userListLength);
        _totalAmount = 0;

        for (uint i = 0; i < _userListLength; i++) {
            _valueList[i] = seedContributionMap[_token][_userList[i]];
            _totalAmount += _valueList[i];
        }
    }

    function getUserTokenCursor(IERC20 _token, address _account) external view returns (uint) {
        return userTokenCursorMap[_token][_account];
    }

    function setUserTokenCursor(IERC20 _token, address _account, uint _cursor) external isSetter {
        userTokenCursorMap[_token][_account] = _cursor;
    }

    error CugarStore__InvalidLength();
}
