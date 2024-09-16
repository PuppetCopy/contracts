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
    mapping(IERC20 => uint) cursorBalanceMap;
    mapping(IERC20 => mapping(uint => uint)) cursorRateMap;
    mapping(IERC20 => mapping(address => uint)) userCursorMap;
    mapping(IERC20 => mapping(address => uint)) userContributionBalanceMap;
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

    function getCursorBalance(IERC20 _token) external view returns (uint) {
        return cursorBalanceMap[_token];
    }

    function setCursorBalance(IERC20 _token, uint _value) external auth {
        cursorBalanceMap[_token] = _value;
    }

    function getCursorRate(IERC20 _token, uint _cursor) external view returns (uint) {
        return cursorRateMap[_token][_cursor];
    }

    function setCursorRate(IERC20 _token, uint _cursor, uint _value) external auth {
        cursorRateMap[_token][_cursor] = _value;
    }

    function getUserCursor(IERC20 _token, address _user) external view returns (uint) {
        return userCursorMap[_token][_user];
    }

    function setUserCursor(IERC20 _token, address _user, uint _value) external auth {
        userCursorMap[_token][_user] = _value;
    }

    function getUserContributionBalanceMap(IERC20 _token, address _user) external view returns (uint) {
        return userContributionBalanceMap[_token][_user];
    }

    function setUserContributionBalanceMap(IERC20 _token, address _user, uint _value) external auth {
        userContributionBalanceMap[_token][_user] = _value;
    }

    function contribute(
        IERC20 _token, //
        BankStore _bank,
        address _user,
        uint _amount
    ) external auth {
        uint _cursor = cursorMap[_token];
        uint _userCursor = userCursorMap[_token][_user];

        _updateCursorReward(_token, _user, _cursor, _userCursor);
        userContributionBalanceMap[_token][_user] += _amount;
        cursorBalanceMap[_token] += _amount;

        interIn(_token, _bank, _amount);
    }

    function contributeMany(
        IERC20 _token,
        BankStore _bank,
        address[] calldata _userList,
        uint[] calldata _valueList
    ) external auth {
        uint _cursor = cursorMap[_token];
        uint _totalAmount = 0;

        for (uint i = 0; i < _userList.length; i++) {
            address user = _userList[i];
            uint value = _valueList[i];
            uint userCursor = userCursorMap[_token][user];

            _updateCursorReward(_token, user, _cursor, userCursor);

            userContributionBalanceMap[_token][user] += value;
            cursorBalanceMap[_token] += value;
            _totalAmount += value;
        }

        interIn(_token, _bank, _totalAmount);
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

    function getPendingCursorReward(IERC20 _token, address _user) public view returns (uint) {
        uint _cursor = cursorMap[_token];
        uint _userCursor = userCursorMap[_token][_user];

        if (_cursor > _userCursor) {
            return userContributionBalanceMap[_token][_user] * cursorRateMap[_token][_userCursor]
                / Precision.FLOAT_PRECISION;
        }
        return 0;
    }

    function getPendingCursorRewardList(
        IERC20[] calldata _tokenList,
        address _user
    ) external view returns (uint[] memory) {
        uint[] memory _cursorBalanceList = new uint[](_tokenList.length);

        for (uint i = 0; i < _tokenList.length; i++) {
            _cursorBalanceList[i] += getPendingCursorReward(_tokenList[i], _user);
        }

        return _cursorBalanceList;
    }

    function _updateCursorReward(IERC20 _token, address _user, uint _cursor, uint _userCursor) internal {
        if (_cursor > _userCursor) {
            userAccruedRewardMap[_user] += userContributionBalanceMap[_token][_user]
                * cursorRateMap[_token][_userCursor] / Precision.FLOAT_PRECISION;
            userContributionBalanceMap[_token][_user] = 0;
            userCursorMap[_token][_user] = _cursor;
        }
    }

    function _updateCursorReward(IERC20 _token, address _user) internal {
        _updateCursorReward(_token, _user, cursorMap[_token], userCursorMap[_token][_user]);
    }

    function updateCursorRewardList(IERC20[] calldata _tokenList, address _user) external auth {
        for (uint i = 0; i < _tokenList.length; i++) {
            _updateCursorReward(_tokenList[i], _user);
        }
    }

    function updateCursorReward(IERC20 _token, address _user) public auth {
        _updateCursorReward(_token, _user);
    }

    error RewardStore__InvalidLength();
}
