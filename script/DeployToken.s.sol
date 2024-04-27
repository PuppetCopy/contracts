// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {PRBTest} from "@prb/test/src/PRBTest.sol";

import {Dictator} from "src/shared/Dictator.sol";
import {Router} from "src/shared/Router.sol";
import {PuppetToken} from "src/tokenomics/PuppetToken.sol";

import {Address, Role} from "script/Const.sol";


contract DeployToken is PRBTest {
    function run() public {
        vm.startBroadcast(vm.envUint("GBC_DEPLOYER_PRIVATE_KEY"));

        // deployContracts();

        vm.stopBroadcast();
    }

    function deployContracts() internal {
        Dictator dictator = Dictator(Address.Dictator);
        PuppetToken puppetToken = new PuppetToken(dictator, PuppetToken.Config({limitFactor: 0.01e30, durationWindow: 1 hours}));
        dictator.setRoleCapability(Role.MINT_PUPPET, address(puppetToken), puppetToken.mint.selector, true);
        dictator.setRoleCapability(Role.MINT_CORE_RELEASE, address(puppetToken), puppetToken.mintCore.selector, true);

        Router router = new Router(dictator, 200_000);
        dictator.setRoleCapability(Role.TOKEN_TRANSFER, address(router), router.transfer.selector, true);
    }
}
