// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {console} from "forge-std/src/console.sol";

import {Dictatorship} from "src/shared/Dictatorship.sol";
import {Allocation} from "src/position/Allocation.sol";
import {VenueManager} from "src/position/VenueManager.sol";
import {SubscriptionPolicy} from "src/position/policies/SubscriptionPolicy.sol";
import {ThrottlePolicy} from "src/position/policies/ThrottlePolicy.sol";
import {IAllocation} from "src/position/interface/IAllocation.sol";

import {BaseScript} from "./BaseScript.s.sol";

contract DeployPosition is BaseScript {
    function run() public {
        vm.startBroadcast(DEPLOYER_PRIVATE_KEY);

        Dictatorship dictatorship = Dictatorship(getDeployedAddress("Dictatorship"));

        VenueManager venueManager = new VenueManager(dictatorship);
        console.log("VenueManager:", address(venueManager));

        Allocation allocation = new Allocation(
            dictatorship,
            Allocation.Config({
                maxPuppetList: 100,
                transferGasLimit: 200_000,
                callGasLimit: 200_000,
                virtualShareOffset: 1e6
            })
        );
        console.log("Allocation:", address(allocation));

        SubscriptionPolicy subscriptionPolicy = new SubscriptionPolicy(dictatorship, IAllocation(address(allocation)));
        ThrottlePolicy throttlePolicy = new ThrottlePolicy(dictatorship);

        console.log("SubscriptionPolicy:", address(subscriptionPolicy));
        console.log("ThrottlePolicy:", address(throttlePolicy));

        vm.stopBroadcast();
    }
}
