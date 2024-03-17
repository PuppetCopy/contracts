// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {StoreController} from "../../utils/StoreController.sol";

contract RewardStore is StoreController {
    struct UserGeneratedRevenue {
        uint amountInToken;
        uint amountInUsd;
        IERC20 token;
    }

    mapping(bytes32 contributionKey => UserGeneratedRevenue) public userGeneratedRevenue;

    constructor(Authority _authority, address _initSetter) StoreController(_authority, _initSetter) {}

    function getUserGeneratedRevenue(bytes32 _contributionKey) external view returns (UserGeneratedRevenue memory) {
        return userGeneratedRevenue[_contributionKey];
    }

    function setUserGeneratedRevenue(bytes32 _contributionKey, UserGeneratedRevenue memory _ugr) external isSetter {
        userGeneratedRevenue[_contributionKey] = _ugr;
    }

    function removeUserGeneratedRevenue(bytes32 _contributionKey) external isSetter {
        delete userGeneratedRevenue[_contributionKey];
    }
}
