// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {PRBTest} from "@prb/test/src/PRBTest.sol";

import {Dictator} from "src/shared/Dictator.sol";
import {Router} from "src/shared/Router.sol";
import {PuppetToken} from "src/token/PuppetToken.sol";
import {VotingEscrow} from "src/token/VotingEscrow.sol";

import {Address} from "script/Const.sol";

contract DeployToken is PRBTest {
    function run() public {
        vm.startBroadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));

        // deployContracts();

        vm.stopBroadcast();
    }

    function deployContracts() internal {
        Dictator dictator = new Dictator(Address.dao);
        PuppetToken puppetToken = new PuppetToken(dictator, PuppetToken.Config({limitFactor: 0.01e30, durationWindow: 1 hours}), Address.dao);
        Router router = new Router(dictator, 200_000);
        VotingEscrow votingEscrow = new VotingEscrow(dictator, router, puppetToken);
    }
}
