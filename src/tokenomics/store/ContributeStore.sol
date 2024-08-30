// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {Router} from "./../../shared/Router.sol";
import {BankStore} from "./../../shared/store/BankStore.sol";
import {Precision} from "./../../utils/Precision.sol";
import {IAuthority} from "./../../utils/interfaces/IAuthority.sol";

contract ContributeStore is BankStore {
    mapping(IERC20 => uint) buybackQuoteMap;
    mapping(IERC20 => uint) cursorMap;
    mapping(IERC20 => mapping(uint => uint)) cursorRewardMap;
    mapping(IERC20 => mapping(address => uint)) userCursorMap;
    mapping(IERC20 => mapping(address => mapping(uint => uint))) userCursorContributionBalanceMap;
    mapping(address => uint) userAccruedRewardMap;

    constructor(IAuthority _authority, Router _router) BankStore(_authority, _router) {}

    function getBuybackQuote(IERC20 _token) external view returns (uint) {
        return buybackQuoteMap[_token];
    }

    function setBuybackQuote(IERC20 _token, uint _value) external auth {
        buybackQuoteMap[_token] = _value;
    }

    function getCursor(IERC20 _token) external view returns (uint) {
        return cursorMap[_token];
    }

    function setCursor(IERC20 _token, uint _value) external auth {
        cursorMap[_token] = _value;
    }

    function getCursorReward(IERC20 _token, uint _cursor) external view returns (uint) {
        return cursorRewardMap[_token][_cursor];
    }

    function setCursorReward(IERC20 _token, uint _cursor, uint _value) external auth {
        cursorRewardMap[_token][_cursor] = _value;
    }

    function getUserCursor(IERC20 _token, address _user) external view returns (uint) {
        return userCursorMap[_token][_user];
    }

    function setUserCursor(IERC20 _token, address _user, uint _value) external auth {
        userCursorMap[_token][_user] = _value;
    }

    function getUserContributionCursor(IERC20 _token, address _user, uint _cursor) external view returns (uint) {
        return userCursorContributionBalanceMap[_token][_user][_cursor];
    }

    function setUserContributionCursor(IERC20 _token, address _user, uint _cursor, uint _value) external auth {
        userCursorContributionBalanceMap[_token][_user][_cursor] = _value;
    }

    function settleUserContributionCursor(IERC20 _token, address _user, uint _cursor) external auth returns (uint) {
        return userCursorContributionBalanceMap[_token][_user][_cursor] = 0;
    }

    function contribute(
        IERC20 _token, //
        address _depositor,
        address _user,
        uint _amount
    ) external auth {
        uint cursor = cursorMap[_token];
        uint userCursor = userCursorMap[_token][_user];

        updateCursor(_token, _user, cursor, userCursor);
        userCursorContributionBalanceMap[_token][_user][cursor] += _amount;

        transferIn(_token, _depositor, _amount);
    }

    function contributeMany(
        IERC20 _token, //
        address _depositor,
        address[] calldata _userList,
        uint[] calldata _valueList
    ) external auth {
        uint cursor = cursorMap[_token];
        uint _toitalAmount = 0;

        for (uint i = 0; i < _userList.length; i++) {
            address user = _userList[i];
            uint value = _valueList[i];

            updateCursor(_token, user, cursor, userCursorMap[_token][user]);

            userCursorContributionBalanceMap[_token][user][cursor] += value;
            _toitalAmount += value;
        }

        transferIn(_token, _depositor, _toitalAmount);
    }

    function getUserAccruedReward(address _user) external view returns (uint) {
        return userAccruedRewardMap[_user];
    }

    function setUserAccruedReward(address _user, uint _value) external auth {
        userAccruedRewardMap[_user] = _value;
    }

    function updateAccruedReward(address _user, uint _value) external auth {
        userAccruedRewardMap[_user] += _value;
    }

    function updateCursor(IERC20 _token, address _user, uint cursor, uint userCursor) public auth {
        if (cursor > userCursor) {
            userAccruedRewardMap[_user] += userCursorContributionBalanceMap[_token][_user][userCursor]
                * cursorRewardMap[_token][userCursor] / Precision.FLOAT_PRECISION;
            userCursorContributionBalanceMap[_token][_user][userCursor] = 0;
            userCursorMap[_token][_user] = cursor;
        }
    }

    function updateCursor(IERC20 _token, address _user) external auth {
        updateCursor(_token, _user, cursorMap[_token], userCursorMap[_token][_user]);
    }

    error RewardStore__InvalidLength();
}
