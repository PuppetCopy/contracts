// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {console} from "forge-std/src/console.sol";

import {Router} from "src/Router.sol";
import {RouterProxy} from "src/RouterProxy.sol";
import {MatchingRule} from "src/position/MatchingRule.sol";
import {MirrorPosition} from "src/position/MirrorPosition.sol";
import {Dictatorship} from "src/shared/Dictatorship.sol";
import {FeeMarketplace} from "src/shared/FeeMarketplace.sol";

import {BaseScript} from "./BaseScript.s.sol";
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
        MirrorPosition mirrorPosition = MirrorPosition(getDeployedAddress("MirrorPosition"));

        Router newRouter = new Router(mirrorPosition, matchingRule, feeMarketplace);

        routerProxy.update(address(newRouter));

        console.log("Router implementation deployed at:", address(newRouter));
        console.log("Seeding MatchingRule with initial rules...");
        matchingRule.setRule(
            mirrorPosition,
            IERC20(Const.usdc),
            DEPLOYER_ADDRESS,
            DEPLOYER_ADDRESS,
            MatchingRule.Rule({allowanceRate: 1000, throttleActivity: 100, expiry: block.timestamp + 30 days})
        );
    }
}
