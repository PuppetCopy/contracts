// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.31;

import {console} from "forge-std/src/console.sol";

import {Dictatorship} from "src/shared/Dictatorship.sol";
import {Allocation} from "src/position/Allocation.sol";
import {AllowedRecipientPolicy} from "src/position/policies/AllowedRecipientPolicy.sol";
import {AllowanceRatePolicy} from "src/position/policies/AllowanceRatePolicy.sol";
import {ThrottlePolicy} from "src/position/policies/ThrottlePolicy.sol";

import {BaseScript} from "./BaseScript.s.sol";

/**
 * @notice Deploy position contracts: Allocation, Policies
 * @dev Allocation is an ERC-7579 executor+hook module installed on trader accounts
 *      Policies are Smart Sessions compatible - users install them via Rhinestone
 *
 * Deployment order:
 * 1. DeployBase.s.sol - deploys Dictatorship, tokens, FeeMarketplace, UserRouterProxy
 * 2. DeployPosition.s.sol - deploys Allocation and policies (this script)
 * 3. DeployUserRouter.s.sol - deploys UserRouter and sets permissions
 */
contract DeployPosition is BaseScript {
    function run() public {
        vm.startBroadcast(DEPLOYER_PRIVATE_KEY);

        // Load existing contracts
        Dictatorship dictatorship = Dictatorship(getDeployedAddress("Dictatorship"));

        // Deploy Allocation (executor + hook module for trader subaccounts)
        // Traders install this as both executor (type 2) and hook (type 4)
        Allocation allocation = new Allocation(
            dictatorship,
            Allocation.Config({maxPuppetList: 100})
        );
        dictatorship.registerContract(allocation);
        console.log("Allocation:", address(allocation));

        // Deploy Smart Sessions policies (stateless, puppets install via Smart Sessions)
        // These validate transfers from puppet accounts to trader subaccounts
        AllowedRecipientPolicy allowedRecipientPolicy = new AllowedRecipientPolicy();
        AllowanceRatePolicy allowanceRatePolicy = new AllowanceRatePolicy();
        ThrottlePolicy throttlePolicy = new ThrottlePolicy();

        console.log("AllowedRecipientPolicy:", address(allowedRecipientPolicy));
        console.log("AllowanceRatePolicy:", address(allowanceRatePolicy));
        console.log("ThrottlePolicy:", address(throttlePolicy));

        vm.stopBroadcast();
    }
}
