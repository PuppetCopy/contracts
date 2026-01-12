// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {Dictatorship} from "src/shared/Dictatorship.sol";
import {IAuthority} from "src/utils/interfaces/IAuthority.sol";
import {Allocate} from "src/position/Allocate.sol";
import {Match} from "src/position/Match.sol";
import {Position} from "src/position/Position.sol";
import {MasterHook} from "src/account/MasterHook.sol";
import {TokenRouter} from "src/shared/TokenRouter.sol";
import {UserRouter} from "src/UserRouter.sol";
import {ProxyUserRouter} from "src/utils/ProxyUserRouter.sol";

import {BaseScript} from "./BaseScript.s.sol";

contract DeployUserRouter is BaseScript {
    function run() public {
        _loadDeployments();

        vm.startBroadcast(DEPLOYER_PRIVATE_KEY);

        Dictatorship dictatorship = Dictatorship(_getChainAddress("Dictatorship"));
        Allocate allocation = Allocate(_getChainAddress("Allocate"));
        Match matcher = Match(_getChainAddress("Match"));
        Position position = Position(_getChainAddress("Position"));
        MasterHook masterHook = MasterHook(_getChainAddress("MasterHook"));
        TokenRouter tokenRouter = TokenRouter(_getChainAddress("TokenRouter"));
        ProxyUserRouter proxyUserRouter = ProxyUserRouter(payable(_getChainAddress("ProxyUserRouter")));

        UserRouter userRouter = new UserRouter(
            IAuthority(address(dictatorship)),
            UserRouter.Config({
                allocation: allocation,
                matcher: matcher,
                position: position,
                tokenRouter: tokenRouter,
                masterHook: address(masterHook)
            })
        );
        proxyUserRouter.update(address(userRouter));

        address proxyAddr = address(proxyUserRouter);
        dictatorship.setPermission(allocation, allocation.createMaster.selector, proxyAddr);

        vm.stopBroadcast();
    }
}
