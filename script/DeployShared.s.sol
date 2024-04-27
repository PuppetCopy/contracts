// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {PRBTest} from "@prb/test/src/PRBTest.sol";

import {Dictator} from "src/shared/Dictator.sol";
import {Router} from "src/shared/Router.sol";
import {PuppetToken} from "src/tokenomics/PuppetToken.sol";

import {Address, Role} from "script/Const.sol";

contract DeployShared is PRBTest {
    function run() public {
        vm.startBroadcast(vm.envUint("GBC_DEPLOYER_PRIVATE_KEY"));

        deployContracts();

        vm.stopBroadcast();
    }

    function deployContracts() internal {
        // Dictator dictator = new Dictator(Address.dao);
        Dictator dictator = Dictator(Address.Dictator);

    }
}
