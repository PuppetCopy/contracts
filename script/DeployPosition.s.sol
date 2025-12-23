// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.31;

import {Dictatorship} from "src/shared/Dictatorship.sol";
import {Allocation} from "src/position/Allocation.sol";
import {PuppetAccount} from "src/position/PuppetAccount.sol";
import {PuppetModule} from "src/position/PuppetModule.sol";
import {SubaccountModule} from "src/position/SubaccountModule.sol";

import {BaseScript} from "./BaseScript.s.sol";

/**
 * @notice Deploy position contracts: Allocation, PuppetAccount, PuppetModule, SubaccountModule
 * @dev Run DeployUserRouter.s.sol after this to deploy UserRouter and set permissions
 */
contract DeployPosition is BaseScript {
    function run() public {
        vm.startBroadcast(DEPLOYER_PRIVATE_KEY);

        // Load existing contracts
        Dictatorship dictatorship = Dictatorship(getDeployedAddress("Dictatorship"));

        // Deploy Allocation first
        Allocation allocation = new Allocation(
            dictatorship,
            Allocation.Config({maxPuppetList: 100})
        );
        dictatorship.registerContract(allocation);

        // Deploy PuppetAccount (stores puppet policy state)
        PuppetAccount puppetAccount = new PuppetAccount(dictatorship);
        dictatorship.registerContract(puppetAccount);

        // Deploy PuppetModule (contains validation logic)
        PuppetModule puppetModule = new PuppetModule(puppetAccount, address(allocation));

        // Deploy SubaccountModule (for trader subaccounts)
        SubaccountModule subaccountModule = new SubaccountModule(allocation);

        // Set permissions for PuppetModule to call PuppetAccount
        dictatorship.setPermission(puppetAccount, puppetAccount.registerPuppet.selector, address(puppetModule));
        dictatorship.setPermission(puppetAccount, puppetAccount.setPolicy.selector, address(puppetModule));
        dictatorship.setPermission(puppetAccount, puppetAccount.removePolicy.selector, address(puppetModule));

        // Set permissions for SubaccountModule to call Allocation
        dictatorship.setPermission(allocation, allocation.registerSubaccount.selector, address(subaccountModule));
        dictatorship.setPermission(allocation, allocation.syncSettlement.selector, address(subaccountModule));
        dictatorship.setPermission(allocation, allocation.syncUtilization.selector, address(subaccountModule));

        vm.stopBroadcast();
    }
}
