// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Dictatorship} from "src/shared/Dictatorship.sol";
import {TokenRouter} from "src/shared/TokenRouter.sol";
import {PuppetToken} from "src/tokenomics/PuppetToken.sol";
import {PuppetVoteToken} from "src/tokenomics/PuppetVoteToken.sol";

import {BaseScript} from "./BaseScript.s.sol";
import {Address} from "./Const.sol";

contract DeployPuppetToken is BaseScript {
    function run() public {
        vm.startBroadcast(DEPLOYER_PRIVATE_KEY);
        deployContracts();
        vm.stopBroadcast();
    }

    function deployContracts() internal {
        Dictatorship dictator = new Dictatorship(Address.dao);
        // Dictatorship dictator = Dictatorship(getDeployedAddress("Dictatorship"));

        PuppetToken puppetToken = new PuppetToken();
        // PuppetToken puppetToken = PuppetToken(getDeployedAddress("PuppetToken"));

        new PuppetVoteToken(dictator);
        TokenRouter router = new TokenRouter(dictator);
        dictator.setPermission(router, router.setTransferGasLimit.selector, Address.dao);

        // Config
        router.setTransferGasLimit(200_000);
    }
}
