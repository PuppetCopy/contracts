// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import {Dictator} from "src/shared/Dictator.sol";
import {Router} from "src/shared/Router.sol";
import {PuppetToken} from "src/tokenomics/PuppetToken.sol";
import {PuppetVoteToken} from "src/tokenomics/PuppetVoteToken.sol";
import {EventEmitter} from "src/utils/EventEmitter.sol";

import {BaseScript} from "./BaseScript.s.sol";
import {Address} from "./Const.sol";

contract DeployPuppet is BaseScript {
    function run() public {
        vm.startBroadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));
        deployContracts();
        vm.stopBroadcast();
    }

    function deployContracts() internal {
        Dictator dictator = new Dictator(Address.dao);
        EventEmitter eventEmitter = new EventEmitter(dictator);

        dictator.setAccess(eventEmitter, getNextCreateAddress());
        new PuppetToken(
            dictator, //
            eventEmitter,
            PuppetToken.Config({limitFactor: 0.01e30, durationWindow: 1 hours}),
            Address.dao
        );
        new PuppetVoteToken(dictator);

        new Router(dictator, 200_000);
    }
}
