// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Router} from "src/Router.sol";
import {RouterProxy} from "src/RouterProxy.sol";
import {MatchingRule} from "src/position/MatchingRule.sol";
import {Dictatorship} from "src/shared/Dictatorship.sol";
import {FeeMarketplace} from "src/shared/FeeMarketplace.sol";

import {BaseScript} from "./BaseScript.s.sol";
import {Address} from "./Const.sol";

contract DeployPuppetLogic is BaseScript {
    function run() public {
        vm.startBroadcast(DEPLOYER_PRIVATE_KEY);
        deployContracts();
        vm.stopBroadcast();
    }

    function deployContracts() internal {
        Dictatorship dictator = Dictatorship(getDeployedAddress("Dictatorship"));
        RouterProxy routerProxy = RouterProxy(payable(getDeployedAddress("RouterProxy")));

        MatchingRule matchingRule = MatchingRule(getDeployedAddress("MatchingRule"));
        dictator.setPermission(matchingRule, matchingRule.setRule.selector, address(routerProxy));
        dictator.setPermission(matchingRule, matchingRule.deposit.selector, address(routerProxy));

        FeeMarketplace feeMarketplace = FeeMarketplace(getDeployedAddress("FeeMarketplace"));
        dictator.setPermission(feeMarketplace, feeMarketplace.acceptOffer.selector, address(routerProxy));

        dictator.setAccess(routerProxy, Address.dao);
        routerProxy.update(
            address(
                new Router(
                    matchingRule, //
                    feeMarketplace
                )
            )
        );
    }
}
