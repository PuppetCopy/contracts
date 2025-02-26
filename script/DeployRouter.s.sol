// // SPDX-License-Identifier: BUSL-1.1
// pragma solidity ^0.8.28;

// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// import {Router} from "src/Router.sol";
// import {AllocationLogic} from "src/position/AllocationLogic.sol";
// import {ExecutionLogic} from "src/position/ExecutionLogic.sol";
// import {RequestLogic} from "src/position/RequestLogic.sol";
// import {PuppetLogic} from "src/position/PuppetLogic.sol";
// import {PuppetStore} from "src/position/store/PuppetStore.sol";
// import {Dictator} from "src/shared/Dictator.sol";
// import {TokenRouter} from "src/shared/TokenRouter.sol";
// import {FeeMarketplace} from "src/tokenomics/FeeMarketplace.sol";

// import {BaseScript} from "./BaseScript.s.sol";
// import {Address} from "./Const.sol";

// contract DeployPuppetLogic is BaseScript {
//     function run() public {
//         vm.startBroadcast(DEPLOYER_PRIVATE_KEY);
//         deployContracts();
//         vm.stopBroadcast();
//     }

//     function deployContracts() internal {
//         Dictator dictator = Dictator(getDeployedAddress("RequestLogic"));

//         Router puppetRouter = new Router(dictator);
//         // dictator.setPermission(puppetLogic, puppetLogic.deposit.selector, address(puppetRouter));
//         // dictator.setPermission(puppetLogic, puppetLogic.withdraw.selector, address(puppetRouter));
//         // dictator.setPermission(puppetLogic, puppetLogic.setMatchRule.selector, address(puppetRouter));
//         // dictator.setPermission(puppetLogic, puppetLogic.setMatchRuleList.selector, address(puppetRouter));
//         dictator.initContract(
//             puppetRouter,
//             abi.encode(
//                 Router.Config({
//                     requestLogic: RequestLogic(getDeployedAddress("RequestLogic")),
//                     allocationLogic: AllocationLogic(getDeployedAddress("AllocationLogic")),
//                     executionLogic: ExecutionLogic(getDeployedAddress("ExecutionLogic")),
//                     puppetLogic: PuppetLogic(getDeployedAddress("RequestLogic")),
//                     feeMarketplace: FeeMarketplace(getDeployedAddress("FeeMarketplace"))
//                 })
//             )
//         );
//     }
// }
