// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {Dictatorship} from "src/shared/Dictatorship.sol";
import {IAuthority} from "src/utils/interfaces/IAuthority.sol";
import {Allocation} from "src/position/Allocation.sol";
import {VenueRegistry} from "src/position/VenueRegistry.sol";
import {UserRouter} from "src/UserRouter.sol";
import {ProxyUserRouter} from "src/utils/ProxyUserRouter.sol";

import {BaseScript} from "./BaseScript.s.sol";

contract DeployUserRouter is BaseScript {
    function run() public {
        vm.startBroadcast(DEPLOYER_PRIVATE_KEY);

        Dictatorship dictatorship = Dictatorship(getDeployedAddress("Dictatorship"));
        Allocation allocation = Allocation(getDeployedAddress("Allocation"));
        VenueRegistry venueRegistry = VenueRegistry(getDeployedAddress("VenueRegistry"));
        ProxyUserRouter proxyUserRouter = ProxyUserRouter(payable(getDeployedAddress("ProxyUserRouter")));

        UserRouter userRouter = new UserRouter(
            IAuthority(address(dictatorship)),
            UserRouter.Config({allocation: allocation, venueRegistry: venueRegistry})
        );
        proxyUserRouter.update(address(userRouter));

        address proxyAddr = address(proxyUserRouter);
        dictatorship.setPermission(allocation, allocation.registerMasterSubaccount.selector, proxyAddr);

        vm.stopBroadcast();
    }
}
