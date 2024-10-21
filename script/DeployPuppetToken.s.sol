// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import {Dictator} from "src/shared/Dictator.sol";
import {Router} from "src/shared/Router.sol";
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
        // Dictator dictator = new Dictator(Address.dao);
        Dictator dictator = Dictator(getContractAddress("Dictator"));

        // PuppetToken puppetToken = new PuppetToken(dictator, Address.dao);
        // PuppetToken puppetToken = PuppetToken(getContractAddress("PuppetToken"));

        new PuppetVoteToken(dictator);
        // Router router = new Router(dictator);
        // dictator.setPermission(router, router.setTransferGasLimit.selector, Address.dao);

        // // Config
        // router.setTransferGasLimit(200_000);
        // dictator.initContract(
        //     puppetToken, abi.encode(PuppetToken.Config({limitFactor: 0.01e30, durationWindow: 1 hours}))
        // );
    }
}
