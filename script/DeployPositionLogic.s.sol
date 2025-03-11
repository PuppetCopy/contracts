// // SPDX-License-Identifier: BUSL-1.1
// pragma solidity ^0.8.28;

// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// import {PositionRouter} from "src/PositionRouter.sol";
// import {PuppetRouter} from "src/PuppetRouter.sol";
// import {AllocationLogic} from "src/position/AllocationLogic.sol";
// import {ExecutionLogic} from "src/position/ExecutionLogic.sol";
// import {RequestLogic} from "src/position/RequestLogic.sol";
// import {UnhandledCallbackLogic} from "src/position/UnhandledCallbackLogic.sol";
// import {IGmxExchangeRouter} from "src/position/interface/IGmxExchangeRouter.sol";
// import {PositionStore} from "src/position/PositionStore.sol";
// import {PositionStore} from "src/position/PositionStore.sol";
// import {PuppetLogic} from "src/position/PuppetLogic.sol";
// import {PuppetStore} from "src/position/PuppetStore.sol";
// import {Dictator} from "src/shared/Dictator.sol";
// import {TokenRouter} from "src/shared/TokenRouter.sol";
// import {PuppetToken} from "src/tokenomics/PuppetToken.sol";
// import {PuppetVoteToken} from "src/tokenomics/PuppetVoteToken.sol";
// import {ContributeStore} from "src/tokenomics/ContributeStore.sol";

// import {BaseScript} from "./BaseScript.s.sol";
// import {Address} from "./Const.sol";

// contract DeployPosition is BaseScript {
//     Dictator dictator = Dictator(getDeployedAddress("Dictator"));

//     function run() public {
//         vm.startBroadcast(DEPLOYER_PRIVATE_KEY);
//         deployContracts();
//         vm.stopBroadcast();
//     }

//     function deployContracts() internal {
//         Router router = Router(getDeployedAddress("Router"));
//         PuppetStore puppetStore = PuppetStore(getDeployedAddress("PuppetStore"));
//         ContributeStore contributeStore = ContributeStore(getDeployedAddress("ContributeStore"));

//         PositionStore positionStore = new PositionStore(dictator, router);
//         dictator.setPermission(router, router.transfer.selector, address(positionStore));
//         PositionRouter positionRouter = new PositionRouter(dictator, positionStore);

//         // PositionStore positionStore = PositionStore(getContractAddress("PositionStore"));
//         // PositionRouter positionRouter = PositionRouter(getContractAddress("PositionRouter"));

//         RequestLogic requestLogic = new RequestLogic(dictator, puppetStore, positionStore);
//         dictator.setAccess(puppetStore, address(requestLogic));
//         dictator.setAccess(positionStore, address(requestLogic));

//         ExecutionLogic executionLogic = new ExecutionLogic(dictator, puppetStore, positionStore);
//         dictator.setAccess(positionStore, address(executionLogic));
//         dictator.setAccess(puppetStore, address(executionLogic));

//         UnhandledCallbackLogic unhandledCallbackLogic = new UnhandledCallbackLogic(dictator, positionStore);

//         AllocationLogic allocationLogic = new AllocationLogic(dictator, contributeStore, puppetStore, positionStore);
//         dictator.setAccess(contributeStore, address(allocationLogic));
//         dictator.setAccess(puppetStore, address(allocationLogic));
//         dictator.setAccess(puppetStore, address(contributeStore));

//         // config
//         dictator.initContract(
//             allocationLogic,
//             abi.encode(
//                 AllocationLogic.Config({
//                     limitAllocationListLength: 50,
//                     performanceContributionRate: 0.1e30,
//                     traderPerformanceContributionShare: 0
//                 })
//             )
//         );
//         dictator.initContract(
//             requestLogic,
//             abi.encode(
//                 RequestLogic.Config({
//                     gmxExchangeRouter: IGmxExchangeRouter(Address.gmxExchangeRouter),
//                     callbackHandler: getDeployedAddress("PositionRouter"),
//                     gmxFundsReciever: getDeployedAddress("PuppetStore"),
//                     gmxOrderVault: Address.gmxOrderVault,
//                     referralCode: Address.referralCode,
//                     increaseCallbackGasLimit: 65_000,
//                     decreaseCallbackGasLimit: 81_000
//                 })
//             )
//         );
//         dictator.initContract(
//             positionRouter,
//             abi.encode(
//                 PositionRouter.Config({
//                     requestLogic: requestLogic,
//                     allocationLogic: allocationLogic,
//                     executionLogic: executionLogic,
//                     unhandledCallbackLogic: unhandledCallbackLogic
//                 })
//             )
//         );

//         // Operation

//         dictator.setPermission(requestLogic, requestLogic.mirror.selector, address(positionRouter));
//         dictator.setPermission(allocationLogic, allocationLogic.allocate.selector, address(positionRouter));
//         dictator.setPermission(allocationLogic, allocationLogic.settle.selector, address(positionRouter));

//         dictator.setPermission(positionRouter, positionRouter.afterOrderExecution.selector, Address.gmxOrderHandler);
//         dictator.setPermission(positionRouter, positionRouter.afterOrderCancellation.selector, Address.gmxOrderHandler);
//         dictator.setPermission(positionRouter, positionRouter.afterOrderFrozen.selector, Address.gmxOrderHandler);
//         dictator.setPermission(positionRouter, positionRouter.mirror.selector, Address.dao);
//         dictator.setPermission(positionRouter, positionRouter.allocate.selector, Address.dao);
//         dictator.setPermission(positionRouter, positionRouter.settle.selector, Address.dao);
//     }
// }
