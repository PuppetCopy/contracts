// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";

import {StoreController} from "../../utils/StoreController.sol";

contract UserGeneratedRevenueStore is StoreController {
    struct Revenue {
        uint amountInToken;
        uint amountInUsd;
    }

    mapping(bytes32 contributionKey => Revenue) public userGeneratedRevenue;

    constructor(Authority _authority, address _initSetter) StoreController(_authority, _initSetter) {}

    function getUserGeneratedRevenue(bytes32 _key) external view returns (Revenue memory) {
        return userGeneratedRevenue[_key];
    }

    function setUserGeneratedRevenue(bytes32 _key, Revenue memory _ugr) external isSetter {
        userGeneratedRevenue[_key] = _ugr;
    }

    function removeUserGeneratedRevenue(bytes32 _key) external isSetter {
        delete userGeneratedRevenue[_key];
    }

    function getUserGeneratedRevenueList(bytes32[] calldata contributionKeyList) external view returns (Revenue[] memory) {
        Revenue[] memory revenueList = new Revenue[](contributionKeyList.length);

        for (uint i = 0; i < contributionKeyList.length; i++) {
            revenueList[i] = userGeneratedRevenue[contributionKeyList[i]];
        }

        return revenueList;
    }

    function setUserGeneratedRevenueList(bytes32[] calldata contributionKeyList, Revenue[] calldata revenueList) external isSetter {
        if (contributionKeyList.length != revenueList.length) revert UserGeneratedRevenueStore__InvalidInputLength();

        for (uint i = 0; i < contributionKeyList.length; i++) {
            userGeneratedRevenue[contributionKeyList[i]] = revenueList[i];
        }
    }

    function removeUserGeneratedRevenueList(bytes32[] calldata contributionKeyList) external isSetter {
        for (uint i = 0; i < contributionKeyList.length; i++) {
            delete userGeneratedRevenue[contributionKeyList[i]];
        }
    }

    error UserGeneratedRevenueStore__InvalidInputLength();
}
