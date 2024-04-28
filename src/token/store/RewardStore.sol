// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Auth} from "./../../utils/auth/Auth.sol";
import {IAuthority} from "./../../utils/interfaces/IAuthority.sol";

import {BankStore} from "./../../shared/store/BankStore.sol";
import {Router} from "./../../shared/Router.sol";

uint constant CURSOR_INTERVAL = 1 weeks; // all future times are rounded by week

contract RewardStore is BankStore {
    mapping(IERC20 => mapping(uint cursorTime => uint)) cursorBalanceMap;
    mapping(IERC20 => mapping(uint cursorTime => uint)) cursorVeSupplyMap;

    mapping(IERC20 => mapping(address => uint)) userSeedContributionMap;
    mapping(IERC20 => mapping(address => uint)) public userTokenCursorMap;

    constructor(IAuthority _authority, Router _router) BankStore(_authority, _router) {}

    function getSeedContribution(IERC20 _token, address _user) external view returns (uint) {
        return userSeedContributionMap[_token][_user];
    }

    function increaseUserSeedContributionList(
        IERC20 _token, //
        uint _cursor,
        address _depositor,
        address[] calldata _userList,
        uint[] calldata _valueList
    ) external auth {
        uint _valueListLength = _valueList.length;
        uint _totalAmount = 0;

        if (_valueListLength != _valueList.length) revert RewardStore__InvalidLength();

        for (uint i = 0; i < _valueListLength; i++) {
            userSeedContributionMap[_token][_userList[i]] += _valueList[i];
            _totalAmount += _valueList[i];
        }

        cursorBalanceMap[_token][_cursor] += _totalAmount;
        _transferIn(_token, _depositor, _totalAmount);
    }

    function increaseUserSeedContribution(IERC20 _token, uint _cursor, address _depositor, address _user, uint _value) external auth {
        userSeedContributionMap[_token][_user] += _value;
        cursorBalanceMap[_token][_cursor] += _value;
        _transferIn(_token, _depositor, _value);
    }

    function decreaseUserSeedContribution(IERC20 _token, address _user, uint _value) external auth {
        userSeedContributionMap[_token][_user] -= _value;
    }

    function setCursorBalance(IERC20 _token, uint _cursor, uint _value) external auth {
        cursorBalanceMap[_token][_cursor] = _value;
    }

    function getCursorBalance(IERC20 _token, uint _cursor) external view returns (uint) {
        return cursorBalanceMap[_token][_cursor];
    }

    function getCursorVeSupply(IERC20 _token, uint _cursor) external view returns (uint) {
        return cursorVeSupplyMap[_token][_cursor];
    }

    function getCursorVeSupplyAndBalance(IERC20 _token, uint _cursor) external view returns (uint _veSupply, uint _cursorBalance) {
        _veSupply = cursorVeSupplyMap[_token][_cursor];
        _cursorBalance = cursorBalanceMap[_token][_cursor];
    }

    function setVeSupply(IERC20 _token, uint _cursor, uint _value) external auth {
        cursorVeSupplyMap[_token][_cursor] = _value;
    }

    function transferOut(IERC20 _token, address _receiver, uint _value) external auth {
        _transferOut(_token, _receiver, _value);
    }

    function getSeedContributionList(
        IERC20 _token, //
        address[] calldata _userList
    ) external view returns (uint _totalAmount, uint[] memory _valueList) {
        uint _userListLength = _userList.length;

        _valueList = new uint[](_userListLength);
        _totalAmount = 0;

        for (uint i = 0; i < _userListLength; i++) {
            _valueList[i] = userSeedContributionMap[_token][_userList[i]];
            _totalAmount += _valueList[i];
        }
    }

    function getUserTokenCursor(IERC20 _token, address _account) external view returns (uint) {
        return userTokenCursorMap[_token][_account];
    }

    function setUserTokenCursor(IERC20 _token, address _account, uint _cursor) external auth {
        userTokenCursorMap[_token][_account] = _cursor;
    }

    error RewardStore__InvalidLength();
}
