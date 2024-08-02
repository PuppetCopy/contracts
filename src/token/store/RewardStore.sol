// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {Auth} from "./../../utils/access/Auth.sol";
import {IAuthority} from "./../../utils/interfaces/IAuthority.sol";

import {BankStore} from "./../../shared/store/BankStore.sol";
import {Router} from "./../../shared/Router.sol";

contract RewardStore is BankStore {
    struct UserTokenCursor {
        uint rewardPerToken;
        uint accruedReward;
    }

    mapping(IERC20 => uint) rewardPerTokenCursorMap;
    mapping(IERC20 => uint) tokenEmissionRateMap;
    mapping(IERC20 => uint) tokenEmissionTimestampMap;

    mapping(IERC20 => uint) buybackTokenThresholdAmountMap;

    mapping(IERC20 token => mapping(address user => UserTokenCursor)) userTokenCursorMap;
    mapping(IERC20 => mapping(address source => uint)) sourceCommitEpochMap;

    mapping(IERC20 => uint) tokenPerContributionCursorMap;
    mapping(IERC20 => mapping(address => uint)) userTokenPerContributionCursorMap;

    mapping(IERC20 => mapping(address => uint)) userContributionMap;

    constructor(
        IAuthority _authority, //
        Router _router,
        IERC20[] memory _tokenBuybackThresholdList,
        uint[] memory _tokenBuybackThresholdAmountList
    ) BankStore(_authority, _router) {
        if (_tokenBuybackThresholdList.length != _tokenBuybackThresholdAmountList.length) revert RewardStore__InvalidLength();

        for (uint i; i < _tokenBuybackThresholdList.length; i++) {
            IERC20 _token = _tokenBuybackThresholdList[i];
            buybackTokenThresholdAmountMap[_token] = _tokenBuybackThresholdAmountList[i];
        }
    }

    function getBuybackTokenThresholdAmount(IERC20 _token) external view returns (uint) {
        return buybackTokenThresholdAmountMap[_token];
    }

    function setBuybackTokenThresholdAmount(IERC20 _token, uint _value) external auth {
        buybackTokenThresholdAmountMap[_token] = _value;
    }

    function getUserContribution(IERC20 _token, address _user) external view returns (uint) {
        return userContributionMap[_token][_user];
    }

    function increaseTokenPerContributionCursor(IERC20 _token, uint _value) external auth returns (uint) {
        return tokenPerContributionCursorMap[_token] += _value;
    }

    function getTokenPerContributionCursor(IERC20 _token) external view returns (uint) {
        return tokenPerContributionCursorMap[_token];
    }

    function getUserTokenPerContributionCursor(IERC20 _token, address _user) external view returns (uint) {
        return userTokenPerContributionCursorMap[_token][_user];
    }

    function setUserTokenPerContributionCursor(IERC20 _token, address _user, uint _value) external auth {
        userTokenPerContributionCursorMap[_token][_user] = _value;
    }

    function commitRewardList(
        IERC20 _token, //
        address _source,
        address[] calldata _userList,
        uint[] calldata _valueList,
        address _trader,
        uint _performanceFee
    ) external auth {
        uint _valueListLength = _valueList.length;
        uint _totalAmount = 0;

        if (_valueListLength != _valueList.length) revert RewardStore__InvalidLength();

        if (_performanceFee > 0) userContributionMap[_token][_trader] += _performanceFee;

        for (uint i = 0; i < _valueListLength; i++) {
            userContributionMap[_token][_userList[i]] += _valueList[i];
            _totalAmount += _valueList[i];
        }

        _transferIn(_token, _source, _totalAmount + _performanceFee);
    }

    function commitReward(
        IERC20 _token, //
        address _source,
        address _user,
        uint _value
    ) external auth {
        userContributionMap[_token][_user] += _value;
        _transferIn(_token, _source, _value);
    }

    function getSourceCommitEpochMap(IERC20 _token, address _source) external view returns (uint) {
        return sourceCommitEpochMap[_token][_source];
    }

    function getRewardPerTokenCursor(IERC20 _token) external view returns (uint) {
        return rewardPerTokenCursorMap[_token];
    }

    function increaseRewardPerTokenCursor(IERC20 _token, uint _amount) external auth returns (uint) {
        return rewardPerTokenCursorMap[_token] += _amount;
    }

    function getTokenEmissionRate(IERC20 _token) external view returns (uint) {
        return tokenEmissionRateMap[_token];
    }

    function setTokenEmissionRate(IERC20 _token, uint _value) external auth {
        tokenEmissionRateMap[_token] = _value;
    }

    function getTokenEmissionTimestamp(IERC20 _token) external view returns (uint) {
        return tokenEmissionTimestampMap[_token];
    }

    function setTokenEmissionTimestamp(IERC20 _token, uint _value) external auth {
        tokenEmissionTimestampMap[_token] = _value;
    }

    function getUserTokenCursor(IERC20 _token, address _user) external view returns (UserTokenCursor memory) {
        return userTokenCursorMap[_token][_user];
    }

    function setUserTokenCursor(IERC20 _token, address _user, UserTokenCursor calldata cursor) external auth {
        userTokenCursorMap[_token][_user] = cursor;
    }

    function increaseUserSeedContribution(IERC20 _token, address _user, uint _value) external auth {
        userContributionMap[_token][_user] += _value;
    }

    function decreaseUserSeedContribution(IERC20 _token, address _user, uint _value) external auth {
        userContributionMap[_token][_user] -= _value;
    }

    function transferOut(IERC20 _token, address _receiver, uint _value) external auth {
        _transferOut(_token, _receiver, _value);
    }

    function transferIn(IERC20 _token, address _depositor, uint _value) external auth {
        _transferIn(_token, _depositor, _value);
    }

    error RewardStore__InvalidLength();
}
