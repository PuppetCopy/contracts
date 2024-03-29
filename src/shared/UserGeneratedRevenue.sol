// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Precision} from "./../utils/Precision.sol";
import {UserGeneratedRevenueStore} from "./store/UserGeneratedRevenueStore.sol";
import {VeRevenueDistributor} from "./../tokenomics/VeRevenueDistributor.sol";

contract UserGeneratedRevenue is Auth {
    function getClaimableAmount(uint distributionRatio, uint tokenAmount) public pure returns (uint) {
        return Precision.applyBasisPoints(tokenAmount, distributionRatio);
    }

    function getUserGeneratedRevenue(UserGeneratedRevenueStore ugrStore, bytes32 key)
        public
        view
        returns (UserGeneratedRevenueStore.Revenue memory)
    {
        return ugrStore.getUserGeneratedRevenue(key);
    }

    function getUserGeneratedRevenueList(UserGeneratedRevenueStore ugrStore, bytes32[] calldata keyList)
        external
        view
        returns (UserGeneratedRevenueStore.Revenue[] memory)
    {
        return ugrStore.getUserGeneratedRevenueList(keyList);
    }

    constructor(Authority _authority) Auth(address(0), _authority) {}

    function increaseUserGeneratedRevenue(
        UserGeneratedRevenueStore ugrStore,
        VeRevenueDistributor distributor,
        bytes32 key,
        UserGeneratedRevenueStore.Revenue memory increase
    ) external requiresAuth {
        UserGeneratedRevenueStore.Revenue memory revenue = ugrStore.getUserGeneratedRevenue(key);
        revenue.amountInToken += increase.amountInToken;
        revenue.amountInUsd += increase.amountInUsd;

        // distributor.depositToken(revenue.token, revenue.amountInToken);
        ugrStore.setUserGeneratedRevenue(key, revenue);
    }

    function claimUserGeneratedRevenueList(UserGeneratedRevenueStore ugrStore, address to, bytes32[] calldata keyList)
        external
        requiresAuth
        returns (UserGeneratedRevenueStore.Revenue[] memory revenueList, uint totalClaimedInUsd)
    {
        totalClaimedInUsd;

        revenueList = ugrStore.getUserGeneratedRevenueList(keyList);

        for (uint i = 0; i < revenueList.length; i++) {
            UserGeneratedRevenueStore.Revenue memory revenue = revenueList[i];
            totalClaimedInUsd += revenue.amountInUsd;

            // revenue.token.transfer(to, revenue.amountInToken);
        }
    }

    function increaseUserGeneratedRevenueList(
        IERC20 token,
        uint[] calldata amounts,
        address[] calldata user,
        UserGeneratedRevenueStore ugrStore,
        VeRevenueDistributor distributor
    ) external requiresAuth {
        if (amounts.length != user.length) revert UserGeneratedRevenue__InvalidInputLength();

        uint totalAmountIn;

        UserGeneratedRevenueStore.Revenue[] memory currentRevenueList = new UserGeneratedRevenueStore.Revenue[](user.length);
        bytes32[] memory keyList = new bytes32[](user.length);

        for (uint i = 0; i < user.length; i++) {
            // currentRevenueList[i] = UserGeneratedRevenueStore.Revenue({from: user[i], amountInToken: amounts[i], amountInUsd: 0, token: token});
            totalAmountIn += amounts[i];
        }

        distributor.depositToken(token, totalAmountIn);
        ugrStore.setUserGeneratedRevenueList(keyList, currentRevenueList);
    }

    function removeUserGeneratedRevenueList(UserGeneratedRevenueStore ugrStore, bytes32[] calldata contributionKeyList) external requiresAuth {
        ugrStore.removeUserGeneratedRevenueList(contributionKeyList);
    }

    error UserGeneratedRevenue__InvalidInputLength();
}
