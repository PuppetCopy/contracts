// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IRateProvider} from "../interfaces/IRateProvider.sol";

interface IWeightedPoolFactory {
    function create(
        string memory name,
        string memory symbol,
        IERC20[] memory tokens,
        uint[] memory normalizedWeights,
        IRateProvider[] memory rateProviders,
        uint swapFeePercentage,
        address owner,
        bytes32 salt
    ) external returns (address);
}
