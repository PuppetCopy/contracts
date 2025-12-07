// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.31;

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

        // Deploy PUPPET token on Arbitrum (home chain - single source of truth)
        PuppetToken puppetToken = new PuppetToken(Const.dao);

        // Deploy governance token
        PuppetVoteToken puppetVoteToken = new PuppetVoteToken(dictatorship);

        TokenRouter tokenRouter = new TokenRouter(dictatorship, TokenRouter.Config(200_000));
        dictatorship.registerContract(tokenRouter);
        RouterProxy routerProxy = new RouterProxy(dictatorship);

        dictatorship.setAccess(routerProxy, Const.dao);
    }
}
