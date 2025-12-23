// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.31;

import {Dictatorship} from "src/shared/Dictatorship.sol";
import {Account as PuppetAccount} from "src/position/Account.sol";
import {Subscribe} from "src/position/Subscribe.sol";
import {Allocation} from "src/position/Allocation.sol";
import {UserRouter} from "src/UserRouter.sol";
import {UserRouterProxy} from "src/utils/UserRouterProxy.sol";

import {BaseScript} from "./BaseScript.s.sol";

/**
 * @notice Deploy UserRouter implementation and set it on the proxy
 * @dev Permissions are set on the PROXY address (not implementation) because
 *      delegatecall preserves msg.sender as the proxy when making external calls
 */
contract DeployUserRouter is BaseScript {
    function run() public {
        vm.startBroadcast(DEPLOYER_PRIVATE_KEY);

        // Load existing contracts
        Dictatorship dictatorship = Dictatorship(getDeployedAddress("Dictatorship"));
        PuppetAccount account = PuppetAccount(getDeployedAddress("Account"));
        Subscribe subscribe = Subscribe(getDeployedAddress("Subscribe"));
        Allocation allocation = Allocation(getDeployedAddress("Allocation"));
        UserRouterProxy userRouterProxy = UserRouterProxy(payable(getDeployedAddress("UserRouterProxy")));

        // Deploy UserRouter implementation
        UserRouter userRouter = new UserRouter(
            account,
            subscribe,
            allocation
        );

        // Set implementation on proxy
        userRouterProxy.update(address(userRouter));

        // Permissions are set on the PROXY address since delegatecall preserves msg.sender
        address proxyAddr = address(userRouterProxy);

        // Account permissions
        dictatorship.setPermission(account, account.deposit.selector, proxyAddr);
        dictatorship.setPermission(account, account.withdraw.selector, proxyAddr);

        // Subscribe permissions
        dictatorship.setPermission(subscribe, subscribe.rule.selector, proxyAddr);

        // Allocation permissions
        dictatorship.setPermission(allocation, allocation.allocate.selector, proxyAddr);
        dictatorship.setPermission(allocation, allocation.settle.selector, proxyAddr);
        dictatorship.setPermission(allocation, allocation.realize.selector, proxyAddr);
        dictatorship.setPermission(allocation, allocation.withdraw.selector, proxyAddr);

        vm.stopBroadcast();
    }
}
