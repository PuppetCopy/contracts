// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Script} from "forge-std/src/Script.sol";

import {Dictator} from "src/shared/Dictator.sol";
import {Router} from "src/shared/Router.sol";
import {EventEmitter} from "src/utils/EventEmitter.sol";

import {VotingEscrowStore} from "src/tokenomics/store/VotingEscrowStore.sol";

import {PuppetToken} from "src/tokenomics/PuppetToken.sol";
import {PuppetVoteToken} from "src/tokenomics/PuppetVoteToken.sol";
import {VotingEscrowLogic} from "src/tokenomics/VotingEscrowLogic.sol";

import {Address} from "script/Const.sol";

contract DeployToken is Script {
    function run() public {
        vm.startBroadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));

        // deployContracts();

        vm.stopBroadcast();
    }

    function deployContracts() internal {
        Dictator dictator = new Dictator(Address.dao);
        PuppetToken puppetToken =
            new PuppetToken(dictator, PuppetToken.Config({limitFactor: 0.01e30, durationWindow: 1 hours}), Address.dao);
        EventEmitter eventEmitter = new EventEmitter(dictator);

        PuppetVoteToken puppetVoteToken = new PuppetVoteToken(dictator);
        VotingEscrowStore votingEscrowStore = new VotingEscrowStore(dictator);
        Router router = new Router(dictator, 200_000);
        VotingEscrowLogic votingEscrow =
            new VotingEscrowLogic(dictator, eventEmitter, router, puppetToken, puppetVoteToken, votingEscrowStore);
    }
}
