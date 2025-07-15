// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import {Dictatorship} from "src/shared/Dictatorship.sol";
import {TokenRouter} from "src/shared/TokenRouter.sol";
import {PuppetToken} from "src/tokenomics/PuppetToken.sol";
import {PuppetVoteToken} from "src/tokenomics/PuppetVoteToken.sol";
import {RouterProxy} from "src/utils/RouterProxy.sol";

import {BaseScript} from "./BaseScript.s.sol";
import {Const} from "./Const.sol";

contract DeployBase is BaseScript {
    function run() public {
        vm.startBroadcast(DEPLOYER_PRIVATE_KEY);
        deployContracts();
        vm.stopBroadcast();
    }

    function deployContracts() internal {
        Dictatorship dictatorship = new Dictatorship(Const.dao);

        new PuppetToken(Const.dao);
        // new PuppetVoteToken(dictatorship);
        TokenRouter tokenRouter = new TokenRouter(dictatorship, TokenRouter.Config(200_000));
        dictatorship.registerContract(tokenRouter);
        RouterProxy routerProxy = new RouterProxy(dictatorship);

        dictatorship.setAccess(routerProxy, Const.dao);
    }
}
