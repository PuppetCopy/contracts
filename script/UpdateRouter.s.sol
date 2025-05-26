// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {console} from "forge-std/src/console.sol";

import {BaseScript} from "./BaseScript.s.sol";
import {Router} from "src/Router.sol";
import {RouterProxy} from "src/RouterProxy.sol";
import {MatchingRule} from "src/position/MatchingRule.sol";
import {Dictatorship} from "src/shared/Dictatorship.sol";
import {FeeMarketplace} from "src/shared/FeeMarketplace.sol";

import {Const} from "./Const.sol";

contract UpdateRouter is BaseScript {
    function run() public {
        vm.startBroadcast(DEPLOYER_PRIVATE_KEY);
        updateRouter();
        vm.stopBroadcast();
    }

    function updateRouter() internal {
        RouterProxy routerProxy = RouterProxy(payable(getDeployedAddress("RouterProxy")));
        MatchingRule matchingRule = MatchingRule(getDeployedAddress("MatchingRule"));
        FeeMarketplace feeMarketplace = FeeMarketplace(getDeployedAddress("FeeMarketplace"));

        require(address(routerProxy) != address(0), "RouterProxy not found");
        require(address(matchingRule) != address(0), "MatchingRule not found");
        require(address(feeMarketplace) != address(0), "FeeMarketplace not found");

        // Deploy new Router implementation
        Router newRouter = new Router(matchingRule, feeMarketplace);

        // Update proxy to point to new implementation
        routerProxy.update(address(newRouter));

        console.log("Router implementation deployed at:", address(newRouter));

        console.log("Seeding MatchingRule with initial rules...");
        matchingRule.setRule(
            IERC20(Const.usdc),
            DEPLOYER_ADDRESS,
            DEPLOYER_ADDRESS,
            MatchingRule.Rule({
                allowanceRate: 1000, // Example value
                throttleActivity: 100, // Example value
                expiry: block.timestamp + 30 days // Example expiry
            })
        );
    }
}
