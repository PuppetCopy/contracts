// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {Router} from "./../../shared/Router.sol";
import {BankStore} from "./../../shared/store/BankStore.sol";
import {IAuthority} from "./../../utils/interfaces/IAuthority.sol";

contract RewardStore is BankStore {
    struct UserRewardCursor {
        uint rewardPerToken;
        uint accruedReward;
    }

    struct EmissionRate {
        uint twa;
        uint timestamp;
    }

    uint public cumulativeRewardPerToken;
    mapping(address user => UserRewardCursor) userRewardCursorMap;

    uint public rewardRate;
    uint public lastDistributionTimestamp;

    EmissionRate public emissionRate;

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

    function setRewardRate(uint _value) external auth {
        rewardRate = _value;
    }

    function setLastDistributionTimestamp(uint _value) external auth {
        lastDistributionTimestamp = _value;
    }

    function setEmissionRate(EmissionRate calldata _value) external auth {
        emissionRate = _value;
    }

    function getEmissionRate() external view returns (EmissionRate memory) {
        return emissionRate;
    }
}
