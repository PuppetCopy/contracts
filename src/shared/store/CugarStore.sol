// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {BankStore} from "./../../utils/BankStore.sol";
import {Router} from "./../../utils/Router.sol";

contract CugarStore is BankStore {
    mapping(uint cursorTime => uint) cursorVeSupplyMap;
    mapping(IERC20 => mapping(uint cursorTime => uint)) cursorBalanceMap;

    mapping(IERC20 => mapping(address => uint)) userCommitMap;
    mapping(IERC20 => mapping(address => uint)) public userTokenCursorMap;

    constructor(Authority _authority, Router _router, address _initSetter) BankStore(_authority, _router, _initSetter) {}

    function setCursorVeSupply(uint _cursor, uint _value) external isSetter {
        cursorVeSupplyMap[_cursor] = _value;
    }

    function getCursorVeSupply(uint _cursor) external view returns (uint) {
        return cursorVeSupplyMap[_cursor];
    }

    function increaseCommitList(
        IERC20 _token, //
        uint _cursor,
        address _depositor,
        address[] calldata _userList,
        uint[] calldata _amountList
    ) external isSetter {
        uint _amountListLength = _amountList.length;
        uint _totalAmount = 0;

        if (_amountListLength != _amountList.length) revert CugarStore__InvalidLength();

        for (uint i = 0; i < _amountListLength; i++) {
            userCommitMap[_token][_userList[i]] += _amountList[i];
            _totalAmount += _amountList[i];
        }

        cursorBalanceMap[_token][_cursor] += _totalAmount;
        transferIn(_token, _depositor, _totalAmount);
    }

    function increaseCommit(IERC20 _token, uint _cursor, address _depositor, address _user, uint _amount) external isSetter {
        userCommitMap[_token][_user] += _amount;
        cursorBalanceMap[_token][_cursor] += _amount;
        transferIn(_token, _depositor, _amount);
    }

    function decreaseCommit(IERC20 _token, address _user, uint _amount) external isSetter {
        userCommitMap[_token][_user] -= _amount;
    }

    function getCommit(IERC20 _token, address _user) external view returns (uint) {
        return userCommitMap[_token][_user];
    }

    function getCursorBalance(IERC20 _token, uint _cursor) external view returns (uint) {
        return cursorBalanceMap[_token][_cursor];
    }

    function decreaseCursorBalance(IERC20 _token, uint _cursor, address _receiver, uint _amount) external isSetter {
        cursorBalanceMap[_token][_cursor] -= _amount;
        transferOut(_token, _receiver, _amount);
    }

    function getCommitList(IERC20 _token, address[] calldata _userList) external view returns (uint _totalAmount, uint[] memory _userCommitList) {
        uint _userListLength = _userList.length;

        _userCommitList = new uint[](_userListLength);
        _totalAmount = 0;

        for (uint i = 0; i < _userListLength; i++) {
            _userCommitList[i] = userCommitMap[_token][_userList[i]];
            _totalAmount += _userCommitList[i];
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
