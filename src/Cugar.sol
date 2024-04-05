// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Precision} from "./utils/Precision.sol";

import {CugarLogic} from "./shared/logic/CugarLogic.sol";
import {CugarStore} from "./shared/store/CugarStore.sol";

contract Cugar is Auth {
    event RewardRouter__SetConfig(uint timestmap, CallConfig callConfig);

    struct CallConfig {
        CugarStore store;
        CugarLogic.CallClaim claim;
    }

    CallConfig callConfig;

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

    function claim(IERC20 token, address revenueSource, address user, uint maxAcceptableTokenPriceInUsdc) external requiresAuth returns (uint) {
        return CugarLogic.claim(callConfig.claim, token, revenueSource, user, maxAcceptableTokenPriceInUsdc);
    }

    // function claimList(bytes32[] calldata keyList) external {
    //     CugarLogic.claimList(callConfig.store, callConfig.revenueDistributor, keyList);
    // }

    function increase(IERC20 token, address account, uint amountInToken) external requiresAuth {
        CugarLogic.increase(callConfig.store, token, account, amountInToken);
    }

    function increaseList(bytes32[] memory keyList, uint[] calldata amountList) external requiresAuth {
        CugarLogic.increaseList(callConfig.store, keyList, amountList);
    }

    function resetCugarList(CugarStore ugrStore, bytes32[] calldata contributionKeyList) external requiresAuth {
        ugrStore.resetCugarList(contributionKeyList);
    }

    // governance

    function setConfig(CallConfig memory _callConfig) external requiresAuth {
        _setConfig(_callConfig);
    }

    // internal

    function _setConfig(CallConfig memory _callConfig) internal {
        callConfig = _callConfig;

        emit RewardRouter__SetConfig(block.timestamp, callConfig);
    }

    error Cugar__InvalidInputLength();
}
