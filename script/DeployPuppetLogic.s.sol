// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {PuppetRouter} from "src/PuppetRouter.sol";
import {MirrorPositionStore} from "src/position/store/MirrorPositionStore.sol";
import {PuppetLogic} from "src/puppet/PuppetLogic.sol";
import {PuppetStore} from "src/puppet/store/PuppetStore.sol";
import {Dictator} from "src/shared/Dictator.sol";
import {Router} from "src/shared/Router.sol";
import {EventEmitter} from "src/utils/EventEmitter.sol";

import {BaseScript} from "./BaseScript.s.sol";
import {Address} from "./Const.sol";

contract DeployPuppetLogic is BaseScript {
    function run() public {
        vm.startBroadcast(DEPLOYER_PRIVATE_KEY);
        deployContracts();
        vm.stopBroadcast();
    }

    function deployContracts() internal {
        Dictator dictator = Dictator(Address.Dictator);
        EventEmitter eventEmitter = EventEmitter(Address.EventEmitter);
        Router router = Router(Address.Router);

        PuppetStore puppetStore = new PuppetStore(dictator, router);
        dictator.setPermission(router, router.transfer.selector, address(puppetStore));

        PuppetRouter puppetRouter = new PuppetRouter(dictator, eventEmitter);
        dictator.setPermission(puppetRouter, puppetRouter.setConfig.selector, Address.dao);
        dictator.setAccess(eventEmitter, address(puppetRouter));

        // PuppetStore puppetStore = PuppetStore(Address.PuppetStore);
        // PuppetRouter puppetRouter = PuppetRouter(Address.PuppetRouter);

        PuppetLogic puppetLogic = new PuppetLogic(dictator, eventEmitter, puppetStore);
        dictator.setPermission(puppetLogic, puppetLogic.setConfig.selector, Address.dao);
        dictator.setAccess(eventEmitter, address(puppetLogic));
        dictator.setAccess(puppetStore, address(puppetLogic));
        dictator.setPermission(puppetLogic, puppetLogic.deposit.selector, address(puppetRouter));
        dictator.setPermission(puppetLogic, puppetLogic.withdraw.selector, address(puppetRouter));
        dictator.setPermission(puppetLogic, puppetLogic.setMatchRule.selector, address(puppetRouter));
        dictator.setPermission(puppetLogic, puppetLogic.setMatchRuleList.selector, address(puppetRouter));

        // config
        IERC20[] memory tokenAllowanceCapList = new IERC20[](2);
        tokenAllowanceCapList[0] = IERC20(Address.wnt);
        tokenAllowanceCapList[1] = IERC20(Address.usdc);
        uint[] memory tokenAllowanceCapAmountList = new uint[](2);
        tokenAllowanceCapAmountList[0] = 0.2e18;
        tokenAllowanceCapAmountList[1] = 500e30;
        puppetLogic.setConfig(
            PuppetLogic.Config({
                minExpiryDuration: 1 days,
                minAllowanceRate: 100, // 10 basis points
                maxAllowanceRate: 10000,
                minAllocationActivity: 3600,
                maxAllocationActivity: 604800,
                tokenAllowanceList: tokenAllowanceCapList,
                tokenAllowanceAmountList: tokenAllowanceCapAmountList
            })
        );
        puppetRouter.setConfig(PuppetRouter.Config({logic: puppetLogic}));
    }
}