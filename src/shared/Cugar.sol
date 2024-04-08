// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {CugarStore} from "./store/CugarStore.sol";
import {VeRevenueDistributor} from "./../tokenomics/VeRevenueDistributor.sol";
import {Router} from "./../utils/Router.sol";

contract Cugar is Auth {
    event RewardRouter__SetConfig(uint timestmap, CallConfig callConfig);

    struct CallConfig {
        CugarStore store;
    }

    CallConfig callConfig;

    function get(bytes32 key) public view returns (uint) {
        return callConfig.store.get(key);
    }

    function getList(bytes32[] calldata keyList) external view returns (uint[] memory) {
        return callConfig.store.getList(keyList);
    }

    constructor(Authority _authority, CallConfig memory _config) Auth(address(0), _authority) {
        _setConfig(_config);
    }

    // integration

    function increase(bytes32 key, uint amountInToken) external requiresAuth {
        callConfig.store.increase(key, amountInToken);
    }

    function increaseList(bytes32[] memory keyList, uint[] calldata amountList) external requiresAuth {
        callConfig.store.increaseList(keyList, amountList);
    }

    function decreaseList(bytes32[] calldata contributionKeyList, uint[] calldata amountList) external requiresAuth {
        callConfig.store.decreaseList(contributionKeyList, amountList);
    }

    function claimAndDistribute(
        Router router, //
        VeRevenueDistributor revenueDistributor,
        bytes32 key,
        address revenueSource,
        IERC20 token,
        uint amount
    ) external requiresAuth {
        revenueDistributor.checkpointToken(token);
        router.transfer(token, revenueSource, address(revenueDistributor), amount);
        revenueDistributor.checkpointToken(token);
        callConfig.store.decrease(key, amount);
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
