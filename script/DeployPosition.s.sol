// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.31;

import {Dictatorship} from "src/shared/Dictatorship.sol";
import {AccountStore} from "src/shared/AccountStore.sol";
import {Account as PuppetAccount} from "src/position/Account.sol";
import {Subscribe} from "src/position/Subscribe.sol";
import {Allocation} from "src/position/Allocation.sol";
import {SubaccountModule} from "src/position/SubaccountModule.sol";

import {BaseScript} from "./BaseScript.s.sol";

/**
 * @notice Deploy position contracts: Account, Subscribe, Allocation, SubaccountModule
 * @dev Run DeployUserRouter.s.sol after this to deploy UserRouter and set permissions
 */
contract DeployPosition is BaseScript {
    function run() public {
        vm.startBroadcast(DEPLOYER_PRIVATE_KEY);

        // Load existing contracts
        Dictatorship dictatorship = Dictatorship(getDeployedAddress("Dictatorship"));

        // Deploy AccountStore
        AccountStore accountStore = new AccountStore(dictatorship);
        dictatorship.setAccess(accountStore, address(this));

        // Deploy Account
        PuppetAccount account = new PuppetAccount(
            dictatorship,
            accountStore,
            PuppetAccount.Config({transferOutGasLimit: 200_000})
        );
        dictatorship.setAccess(accountStore, address(account));
        dictatorship.registerContract(account);

        // Deploy Subscribe
        Subscribe subscribe = new Subscribe(
            dictatorship,
            Subscribe.Config({
                minExpiryDuration: 1 days,
                minAllowanceRate: 100, // 1% min
                maxAllowanceRate: 10000, // 100% max
                minActivityThrottle: 1 hours,
                maxActivityThrottle: 30 days
            })
        );
        dictatorship.registerContract(subscribe);

        // Deploy Allocation
        Allocation allocation = new Allocation(
            dictatorship,
            Allocation.Config({maxPuppetList: 100})
        );
        dictatorship.registerContract(allocation);

        // Deploy SubaccountModule
        SubaccountModule subaccountModule = new SubaccountModule(allocation);

        // Set permissions for SubaccountModule to call Allocation
        dictatorship.setPermission(allocation, allocation.registerSubaccount.selector, address(subaccountModule));
        dictatorship.setPermission(allocation, allocation.syncSettlement.selector, address(subaccountModule));
        dictatorship.setPermission(allocation, allocation.syncUtilization.selector, address(subaccountModule));

        // Set permissions for Subscribe to call Allocation
        dictatorship.setPermission(allocation, allocation.initializeTraderActivityThrottle.selector, address(subscribe));

        // Set permissions for Allocation to call Account
        dictatorship.setPermission(account, account.setUserBalance.selector, address(allocation));
        dictatorship.setPermission(account, account.setBalanceList.selector, address(allocation));
        dictatorship.setPermission(account, account.transferOut.selector, address(allocation));

        vm.stopBroadcast();
    }
}
