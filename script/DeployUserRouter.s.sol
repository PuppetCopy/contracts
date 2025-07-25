// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {console} from "forge-std/src/console.sol";

import {UserRouter} from "src/UserRouter.sol";

import {Deposit} from "src/position/Deposit.sol";
import {Mirror} from "src/position/Mirror.sol";
import {Rule} from "src/position/Rule.sol";
import {Dictatorship} from "src/shared/Dictatorship.sol";
import {FeeMarketplace} from "src/shared/FeeMarketplace.sol";
import {RouterProxy} from "src/utils/RouterProxy.sol";

import {BaseScript} from "./BaseScript.s.sol";
import {Const} from "./Const.sol";

contract DeployUserRouter is BaseScript {
    function run() public {
        vm.startBroadcast(DEPLOYER_PRIVATE_KEY);
        deployUserRouter();
        vm.stopBroadcast();
    }

    Dictatorship dictator = Dictatorship(getDeployedAddress("Dictatorship"));

    function deployUserRouter() internal {
        RouterProxy routerProxy = RouterProxy(payable(getDeployedAddress("RouterProxy")));
        Rule ruleContract = Rule(getDeployedAddress("Rule"));
        Deposit depositContract = Deposit(getDeployedAddress("Deposit"));
        FeeMarketplace feeMarketplace = FeeMarketplace(getDeployedAddress("FeeMarketplace"));
        Mirror mirror = Mirror(getDeployedAddress("Mirror"));

        dictator.setPermission(ruleContract, ruleContract.setRule.selector, address(routerProxy));
        dictator.setPermission(depositContract, depositContract.deposit.selector, address(routerProxy));
        dictator.setPermission(depositContract, depositContract.withdraw.selector, address(routerProxy));
        // dictator.setPermission(feeMarketplace, feeMarketplace.acceptOffer.selector, address(routerProxy));

        UserRouter newRouter = new UserRouter(depositContract, ruleContract, feeMarketplace, mirror);
        routerProxy.update(address(newRouter));

        UserRouter(address(routerProxy)).setMatchingRule(
            IERC20(Const.usdc),
            DEPLOYER_ADDRESS,
            Rule.RuleParams({allowanceRate: 1000, throttleActivity: 1 hours, expiry: block.timestamp + 830 days})
        );
    }
}
