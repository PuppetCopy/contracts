// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.31;

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
 */
contract DeployPosition is BaseScript {
    function run() public {
        vm.startBroadcast(DEPLOYER_PRIVATE_KEY);

        // Load existing contracts
        Dictatorship dictatorship = Dictatorship(getDeployedAddress("Dictatorship"));

        // Deploy Allocation (executor + hook module for trader subaccounts)
        Allocation allocation = new Allocation(
            dictatorship,
            Allocation.Config({maxPuppetList: 100})
        );
        dictatorship.registerContract(allocation);

        // Deploy Smart Sessions policies (stateless, users install via Rhinestone)
        new AllowedRecipientPolicy();
        new AllowanceRatePolicy();
        new ThrottlePolicy();

        vm.stopBroadcast();
    }
}
