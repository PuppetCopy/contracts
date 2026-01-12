// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {Dictatorship} from "src/shared/Dictatorship.sol";
import {Allocate} from "src/position/Allocate.sol";
import {Match} from "src/position/Match.sol";
import {TokenRouter} from "src/shared/TokenRouter.sol";
import {UserRouter} from "src/UserRouter.sol";
import {ProxyUserRouter} from "src/utils/ProxyUserRouter.sol";
import {Registry} from "src/account/Registry.sol";

import {BaseScript} from "./shared/BaseScript.s.sol";

contract DeployUserRouter is BaseScript {
    function run() public {
        Dictatorship dictatorship = Dictatorship(_getUniversalAddress("Dictatorship"));
        Registry registry = Registry(_getUniversalAddress("Registry"));
        Allocate allocation = Allocate(_getChainAddress("Allocate"));
        Match matcher = Match(_getChainAddress("Match"));
        TokenRouter tokenRouter = TokenRouter(_getChainAddress("TokenRouter"));
        ProxyUserRouter proxyUserRouter = ProxyUserRouter(payable(_getChainAddress("ProxyUserRouter")));

        vm.startBroadcast(DEPLOYER_PRIVATE_KEY);

        UserRouter userRouter = new UserRouter(
            dictatorship,
            UserRouter.Config({
                allocation: allocation,
                matcher: matcher,
                tokenRouter: tokenRouter,
                registry: registry
            })
        );
        _setChainAddress("UserRouter", address(userRouter));

        proxyUserRouter.update(address(userRouter));

        vm.stopBroadcast();
    }
}
