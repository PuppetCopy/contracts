// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {PositionUtils} from "./../position/util/PositionUtils.sol";

import {Precision} from "./../utils/Precision.sol";
import {CugarStore} from "./store/CugarStore.sol";

contract Cugar is Auth {
    function getClaimableAmount(uint distributionRatio, uint tokenAmount) public pure returns (uint) {
        return Precision.applyBasisPoints(tokenAmount, distributionRatio);
    }

    function getCugar(CugarStore ugrStore, bytes32 key) public view returns (uint) {
        return ugrStore.getCugar(key);
    }

    function getCugarList(CugarStore ugrStore, bytes32[] calldata keyList) external view returns (uint[] memory) {
        return ugrStore.getCugarList(keyList);
    }

    constructor(Authority _authority) Auth(address(0), _authority) {}

    function increaseCugar(
        CugarStore cugarStore, //
        IERC20 token,
        address account,
        uint amountInToken
    ) external requiresAuth {
        cugarStore.increaseCugar(
            PositionUtils.getCugarKey(token, msg.sender, account), //
            amountInToken
        );
    }

    function claimUserGeneratedRevenueList(bytes32[] calldata contributionKeyList)
        external
        returns (uint[] memory revenueList, uint totalClaimedInUsd)
    {
        for (uint i = 0; i < contributionKeyList.length; i++) {
            // delete userGeneratedRevenueAmountMap[contributionKeyList[i]];
        }
    }

    function increaseCugarList(CugarStore ugrStore, IERC20 token, address[] calldata userList, uint[] calldata amountList) external requiresAuth {
        uint contributorListLength = userList.length;
        if (amountList.length != contributorListLength) revert Cugar__InvalidInputLength();

        bytes32[] memory keyList = new bytes32[](contributorListLength);

        for (uint i = 0; i < contributorListLength; i++) {
            keyList[i] = PositionUtils.getCugarKey(token, msg.sender, userList[i]);
        }

        ugrStore.increaseCugarList(keyList, amountList);
    }

    function resetCugarList(CugarStore ugrStore, bytes32[] calldata contributionKeyList) external requiresAuth {
        ugrStore.resetCugarList(contributionKeyList);
    }

    error Cugar__InvalidInputLength();
}
