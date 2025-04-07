// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {RouterProxy} from "src/RouterProxy.sol";
import {Dictatorship} from "src/shared/Dictatorship.sol";
import {TokenRouter} from "src/shared/TokenRouter.sol";
import {PuppetToken} from "src/tokenomics/PuppetToken.sol";
import {PuppetVoteToken} from "src/tokenomics/PuppetVoteToken.sol";

import {BaseScript} from "./BaseScript.s.sol";
import {Address} from "./Const.sol";

contract DeployPuppetBase is BaseScript {
    function run() public {
        vm.startBroadcast(DEPLOYER_PRIVATE_KEY);
        deployContracts();
        vm.stopBroadcast();
    }

    function deployContracts() internal {
        // Dictatorship dictator = Dictatorship(getDeployedAddress("Dictatorship"));
        Dictatorship dictatorship = new Dictatorship(Address.dao);

        new PuppetToken();
        // new PuppetVoteToken(dictatorship);
        new TokenRouter(dictatorship, 200_000);
        new RouterProxy(dictatorship);
    }
}
