// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {PuppetRouter} from "src/PuppetRouter.sol";
import {PuppetLogic} from "src/puppet/PuppetLogic.sol";
import {PuppetStore} from "src/puppet/store/PuppetStore.sol";
import {Dictator} from "src/shared/Dictator.sol";
import {TokenRouter} from "src/shared/TokenRouter.sol";

import {BaseScript} from "./BaseScript.s.sol";
import {Address} from "./Const.sol";

contract DeployPuppetLogic is BaseScript {
    function run() public {
        vm.startBroadcast(DEPLOYER_PRIVATE_KEY);
        deployContracts();
        vm.stopBroadcast();
    }

    function deployContracts() internal {
        Dictator dictator = Dictator(getDeployedAddress("Dictator"));
        TokenRouter router = TokenRouter(getDeployedAddress("Router"));

        PuppetStore puppetStore = new PuppetStore(dictator, router);
        dictator.setPermission(router, router.transfer.selector, address(puppetStore));
        PuppetRouter puppetRouter = new PuppetRouter(dictator);
        PuppetLogic puppetLogic = new PuppetLogic(dictator, puppetStore);

        dictator.setAccess(puppetStore, address(puppetLogic));
        dictator.setPermission(puppetLogic, puppetLogic.deposit.selector, address(puppetRouter));
        dictator.setPermission(puppetLogic, puppetLogic.withdraw.selector, address(puppetRouter));
        dictator.setPermission(puppetLogic, puppetLogic.setMatchRule.selector, address(puppetRouter));
        dictator.setPermission(puppetLogic, puppetLogic.setMatchRuleList.selector, address(puppetRouter));

        // PuppetStore puppetStore = PuppetStore(getContractAddress("PuppetStore"));
        // PuppetRouter puppetRouter = PuppetRouter(getContractAddress("PuppetRouter"));
        // PuppetLogic puppetLogic = PuppetLogic(getContractAddress("PuppetLogic"));

        // config
        IERC20[] memory tokenAllowanceCapList = new IERC20[](2);
        tokenAllowanceCapList[0] = IERC20(Address.wnt);
        tokenAllowanceCapList[1] = IERC20(Address.usdc);
        uint[] memory tokenAllowanceCapAmountList = new uint[](2);
        tokenAllowanceCapAmountList[0] = 0.2e18;
        tokenAllowanceCapAmountList[1] = 500e30;
        dictator.initContract(
            puppetLogic,
            abi.encode(
                PuppetLogic.Config({
                    minExpiryDuration: 1 days,
                    minAllowanceRate: 100, // 10 basis points
                    maxAllowanceRate: 10000,
                    minAllocationActivity: 3600,
                    maxAllocationActivity: 604800,
                    tokenAllowanceList: tokenAllowanceCapList,
                    tokenAllowanceAmountList: tokenAllowanceCapAmountList
                })
            )
        );
        dictator.initContract(puppetRouter, abi.encode(PuppetRouter.Config({logic: puppetLogic})));
    }
}
