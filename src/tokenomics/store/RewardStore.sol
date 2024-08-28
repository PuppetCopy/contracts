// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {Router} from "./../../shared/Router.sol";
import {BankStore} from "./../../shared/store/BankStore.sol";
import {IAuthority} from "./../../utils/interfaces/IAuthority.sol";

contract RewardStore is BankStore {
    struct UserRewardCursor {
        uint rewardPerToken;
        uint accruedReward;
    }

    uint public cumulativeRewardPerToken;
    uint public tokenRewardRate;
    uint public tokenRewardTimestamp;
    mapping(address user => UserRewardCursor) userRewardCursorMap;

    constructor(IAuthority _authority, Router _router) BankStore(_authority, _router) {}

    function incrementCumulativePerContribution(uint _value) external auth returns (uint) {
        return cumulativeRewardPerToken += _value;
    }

    function getUserRewardCursor(address _user) external view returns (UserRewardCursor memory) {
        return userRewardCursorMap[_user];
    }

    function setUserRewardCursor(address _user, UserRewardCursor calldata cursor) external auth {
        userRewardCursorMap[_user] = cursor;
    }

    function setTokenRewardRate(uint _value) external auth {
        tokenRewardRate = _value;
    }

    function setTokenRewardTimestamp(uint _value) external auth {
        tokenRewardTimestamp = _value;
    }
}
