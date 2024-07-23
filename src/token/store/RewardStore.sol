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
    mapping(IERC20 => mapping(address => uint)) tokenEmissionRateMap;
    mapping(IERC20 => mapping(address => uint)) tokenEmissionTimestampMap;
    mapping(IERC20 => mapping(address => uint)) sourceCommitMap;

    mapping(IERC20 token => mapping(address user => UserTokenCursor)) userTokenCursorMap;

    mapping(IERC20 => mapping(address => uint)) userSeedContributionMap;

    constructor(IAuthority _authority, Router _router) BankStore(_authority, _router) {}

    function getSeedContribution(IERC20 _token, address _user) external view returns (uint) {
        return userSeedContributionMap[_token][_user];
    }

    function commitRewardList(
        IERC20 _token, //
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

        sourceCommitMap[_token][msg.sender] += _totalAmount;
    }

    function commitReward(IERC20 _token, address _user, uint _value) external auth {
        userSeedContributionMap[_token][_user] += _value;
        sourceCommitMap[_token][msg.sender] += _value;
    }

    function getRewardPerTokenCursor(IERC20 _token) external view returns (uint) {
        return rewardPerTokenCursorMap[_token];
    }

    function increaseRewardPerTokenCursor(IERC20 _token, uint _amount) external auth returns (uint) {
        return rewardPerTokenCursorMap[_token] += _amount;
    }

    function getTokenEmissionRate(IERC20 _token, address _source) external view returns (uint) {
        return tokenEmissionRateMap[_token][_source];
    }

    function setTokenEmissionRate(IERC20 _token, address _source, uint _value) external auth {
        tokenEmissionRateMap[_token][_source] = _value;
    }

    function getTokenEmissionTimestamp(IERC20 _token, address _source) external view returns (uint) {
        return tokenEmissionTimestampMap[_token][_source];
    }

    function setTokenEmissionTimestamp(IERC20 _token, address _source, uint _value) external auth {
        tokenEmissionTimestampMap[_token][_source] = _value;
    }

    function getSourceCommit(IERC20 _token, address _source) external view returns (uint) {
        return sourceCommitMap[_token][_source];
    }

    function increaseSourceCommit(IERC20 _token, uint _value) external auth returns (uint) {
        return sourceCommitMap[_token][msg.sender] += _value;
    }

    function decreaseSourceCommit(IERC20 _token, address _source, uint _value) external auth {
        sourceCommitMap[_token][_source] -= _value;
    }

    function getUserTokenCursor(IERC20 _token, address _user) external view returns (UserTokenCursor memory) {
        return userTokenCursorMap[_token][_user];
    }

    function setUserTokenCursor(IERC20 _token, address _user, UserTokenCursor calldata cursor) external auth {
        userTokenCursorMap[_token][_user] = cursor;
    }

    function increaseUserSeedContribution(IERC20 _token, address _user, uint _value) external auth {
        userSeedContributionMap[_token][_user] += _value;
    }

    function decreaseUserSeedContribution(IERC20 _token, address _user, uint _value) external auth {
        userSeedContributionMap[_token][_user] -= _value;
    }

    function transferOut(IERC20 _token, address _receiver, uint _value) external auth {
        _transferOut(_token, _receiver, _value);
    }

    function transferIn(IERC20 _token, address _depositor, uint _value) external auth {
        _transferIn(_token, _depositor, _value);
    }

    error RewardStore__InvalidLength();
}
