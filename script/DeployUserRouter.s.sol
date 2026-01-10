// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {Dictatorship} from "src/shared/Dictatorship.sol";
import {IAuthority} from "src/utils/interfaces/IAuthority.sol";
import {Allocate} from "src/position/Allocate.sol";
import {Match} from "src/position/Match.sol";
import {Position} from "src/position/Position.sol";
import {UserRouter} from "src/UserRouter.sol";
import {ProxyUserRouter} from "src/utils/ProxyUserRouter.sol";

import {BaseScript} from "./BaseScript.s.sol";

contract DeployUserRouter is BaseScript {
    function run() public {
        vm.startBroadcast(DEPLOYER_PRIVATE_KEY);

        Dictatorship dictatorship = Dictatorship(getDeployedAddress("Dictatorship"));
        Allocate allocation = Allocate(getDeployedAddress("Allocate"));
        Match matcher = Match(getDeployedAddress("Match"));
        Position position = Position(getDeployedAddress("Position"));
        ProxyUserRouter proxyUserRouter = ProxyUserRouter(payable(getDeployedAddress("ProxyUserRouter")));

        UserRouter userRouter = new UserRouter(
            IAuthority(address(dictatorship)),
            UserRouter.Config({allocation: allocation, matcher: matcher, position: position})
        );
        proxyUserRouter.update(address(userRouter));

        address proxyAddr = address(proxyUserRouter);
        dictatorship.setPermission(allocation, allocation.createMaster.selector, proxyAddr);

        vm.stopBroadcast();
    }
}
