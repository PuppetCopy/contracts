// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {Auth} from "./../../utils/access/Auth.sol";
import {IAuthority} from "./../../utils/interfaces/IAuthority.sol";

import {Router} from "./../../shared/Router.sol";

contract RewardStore is Auth {
    struct UserEmissionCursor {
        uint rewardPerToken;
        uint accruedReward;
    }

    mapping(IERC20 token => mapping(address user => UserEmissionCursor)) userEmissionRewardMap;
    mapping(IERC20 => uint) tokenEmissionRewardPerTokenCursorMap;
    mapping(IERC20 => uint) tokenEmissionRateMap;
    mapping(IERC20 => uint) tokenEmissionTimestampMap;

    constructor(
        IAuthority _authority, //
        Router _router
    ) Auth(_authority) {}

    function getTokenEmissionRewardPerTokenCursor(IERC20 _token) external view returns (uint) {
        return tokenEmissionRewardPerTokenCursorMap[_token];
    }

    function increaseTokenEmissionRewardPerTokenCursor(IERC20 _token, uint _amount) external auth returns (uint) {
        return tokenEmissionRewardPerTokenCursorMap[_token] += _amount;
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

    function getUserEmissionReward(IERC20 _token, address _user) external view returns (UserEmissionCursor memory) {
        return userEmissionRewardMap[_token][_user];
    }

    function setUserEmissionReward(IERC20 _token, address _user, UserEmissionCursor calldata cursor) external auth {
        userEmissionRewardMap[_token][_user] = cursor;
    }

    error RewardStore__InvalidLength();
}
