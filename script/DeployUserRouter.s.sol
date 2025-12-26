// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

// TODO: Uncomment when UserRouter is ready
/*
import {Dictatorship} from "src/shared/Dictatorship.sol";
import {Allocation} from "src/position/Allocation.sol";
import {UserRouter} from "src/UserRouter.sol";
import {UserRouterProxy} from "src/utils/UserRouterProxy.sol";

import {BaseScript} from "./BaseScript.s.sol";

contract DeployUserRouter is BaseScript {
    function run() public {
        vm.startBroadcast(DEPLOYER_PRIVATE_KEY);

        Dictatorship dictatorship = Dictatorship(getDeployedAddress("Dictatorship"));
        Allocation allocation = Allocation(getDeployedAddress("Allocation"));
        UserRouterProxy userRouterProxy = UserRouterProxy(payable(getDeployedAddress("UserRouterProxy")));

        UserRouter userRouter = new UserRouter(allocation);
        userRouterProxy.update(address(userRouter));

        address proxyAddr = address(userRouterProxy);
        dictatorship.setPermission(allocation, allocation.allocate.selector, proxyAddr);
        dictatorship.setPermission(allocation, allocation.withdraw.selector, proxyAddr);

        vm.stopBroadcast();
    }
}
*/
