// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.31;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {console} from "forge-std/src/console.sol";

import {UserRouter} from "src/UserRouter.sol";

import {Account as AccountContract} from "src/position/Account.sol";
import {Mirror} from "src/position/Mirror.sol";
import {Subscribe} from "src/position/Subscribe.sol";
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
        AccountContract account = AccountContract(getDeployedAddress("Account"));
        Subscribe subscribe = Subscribe(getDeployedAddress("Subscribe"));
        FeeMarketplace feeMarketplace = FeeMarketplace(getDeployedAddress("FeeMarketplace"));
        Mirror mirror = Mirror(getDeployedAddress("Mirror"));

        dictator.setPermission(subscribe, subscribe.rule.selector, address(routerProxy));
        dictator.setPermission(account, account.deposit.selector, address(routerProxy));
        dictator.setPermission(account, account.withdraw.selector, address(routerProxy));
        // dictator.setPermission(feeMarketplace, feeMarketplace.acceptOffer.selector, address(routerProxy));

        UserRouter newRouter = new UserRouter(account, subscribe, feeMarketplace, mirror);
        routerProxy.update(address(newRouter));

        UserRouter(address(routerProxy)).setRule(
            IERC20(Const.usdc),
            DEPLOYER_ADDRESS,
            Subscribe.RuleParams({allowanceRate: 1000, throttleActivity: 1 hours, expiry: block.timestamp + 830 days})
        );
    }
}
