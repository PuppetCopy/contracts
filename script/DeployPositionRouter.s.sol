// // SPDX-License-Identifier: BUSL-1.1
// pragma solidity 0.8.24;

// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import {PRBTest} from "@prb/test/src/PRBTest.sol";
// import {StdUtils} from "forge-std/src/StdUtils.sol";

// import {IGmxExchangeRouter} from "src/position/interface/IGmxExchangeRouter.sol";

// import {IWNT} from "src/utils/interfaces/IWNT.sol";

// import {Dictator} from "src/shared/Dictator.sol";
// import {Router} from "src/shared/Router.sol";

// import {CugarStore} from "src/shared/store/CugarStore.sol";
// import {PuppetStore} from "src/puppet/store/PuppetStore.sol";
// import {PuppetRouter} from "src/puppet/PuppetRouter.sol";

// import {StoreController} from "src/shared/store/StoreController.sol";
// import {SubaccountStore} from "src/shared/store/SubaccountStore.sol";

// import {PositionStore} from "src/position/store/PositionStore.sol";
// import {PositionRouter} from "src/position/PositionRouter.sol";

// import {RequestIncreasePosition} from "src/position/logic/RequestIncreasePosition.sol";
// import {RequestDecreasePosition} from "src/position/logic/RequestDecreasePosition.sol";
// import {ExecuteIncreasePosition} from "src/position/logic/ExecuteIncreasePosition.sol";
// import {ExecuteDecreasePosition} from "src/position/logic/ExecuteDecreasePosition.sol";

// import {Address, Role} from "script/Const.sol";

// contract DeployPuppetRouter is PRBTest, StdUtils {
//     function run() public {
//         vm.startBroadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));
//         deployContracts();
//         vm.stopBroadcast();
//     }

//     function deployContracts() internal {
//         address deployer = vm.envAddress("DEPLOYER_ADDRESS");

//         IERC20 usdc = IERC20(Address.usdc);
//         IWNT wnt = IWNT(Address.wnt);

//         CugarStore cugarStore = CugarStore(Address.CugarStore);

//         Dictator dictator = Dictator(Address.Dictator);
//         Router router = Router(Address.Router);
//         PuppetStore puppetStore = PuppetStore(Address.PuppetStore);
//         PuppetRouter puppetRouter = PuppetRouter(Address.PuppetRouter);

//         address positionRouterAddress = computeCreateAddress(deployer, vm.getNonce(deployer) + 2);

//         StoreController.SetterConfig[] memory setterList = new StoreController.SetterConfig[](1);
//         setterList[0] = StoreController.SetterConfig(positionRouterAddress, true);

//         SubaccountStore subaccountStore = new SubaccountStore(dictator, computeCreateAddress(deployer, vm.getNonce(deployer) + 1));

//         PositionStore positionStore = new PositionStore(dictator, router);
//         PositionRouter positionRouter = new PositionRouter(
//             dictator,
//             PositionRouter.CallConfig({
//                 increase: RequestIncreasePosition.CallConfig({
//                     wnt: wnt,
//                     router: router,
//                     positionStore: positionStore,
//                     gmxExchangeRouter: IGmxExchangeRouter(Address.gmxExchangeRouter),
//                     subaccountStore: subaccountStore,
//                     gmxOrderReciever: address(positionStore),
//                     gmxOrderVault: Address.gmxOrderVault,
//                     referralCode: Address.referralCode,
//                     callbackGasLimit: 2_000_000,
//                     puppetStore: puppetStore,
//                     puppetRouter: puppetRouter,
//                     limitPuppetList: 20,
//                     minimumMatchAmount: 100e30,
//                     tokenTransferGasLimit: 200_000
//                 }),
//                 decrease: RequestDecreasePosition.CallConfig({
//                     wnt: IWNT(Address.wnt),
//                     gmxExchangeRouter: IGmxExchangeRouter(Address.gmxExchangeRouter),
//                     positionStore: positionStore,
//                     subaccountStore: subaccountStore,
//                     gmxOrderReciever: address(positionStore),
//                     gmxOrderVault: Address.gmxOrderVault,
//                     referralCode: Address.referralCode,
//                     callbackGasLimit: 2_000_000,
//                     tokenTransferGasLimit: 200_000
//                 }),
//                 executeIncrease: ExecuteIncreasePosition.CallConfig({
//                     positionStore: positionStore, //
//                     gmxOrderHandler: Address.gmxOrderHandler
//                 }),
//                 executeDecrease: ExecuteDecreasePosition.CallConfig({
//                     router: router,
//                     positionStore: positionStore,
//                     puppetStore: puppetStore,
//                     cugarStore: cugarStore,
//                     gmxOrderReciever: address(positionStore),
//                     tokenTransferGasLimit: 200_000,
//                     performanceFeeRate: 0.1e30, // 10%
//                     traderPerformanceFeeShare: 0.5e30 // shared between trader and platform
//                 })
//             })
//         );
//         dictator.setRoleCapability(Role.EXECUTE_ORDER, address(positionRouter), positionRouter.afterOrderExecution.selector, true);
//         dictator.setRoleCapability(Role.EXECUTE_ORDER, address(positionRouter), positionRouter.afterOrderCancellation.selector, true);
//         dictator.setRoleCapability(Role.EXECUTE_ORDER, address(positionRouter), positionRouter.afterOrderFrozen.selector, true);

//         dictator.setUserRole(address(positionRouter), Role.TOKEN_TRANSFER, true);
//         dictator.setUserRole(address(positionRouter), Role.SUBACCOUNT_CREATE, true);
//         dictator.setUserRole(address(positionRouter), Role.SUBACCOUNT_SET_OPERATOR, true);
//         dictator.setUserRole(address(positionRouter), Role.PUPPET_DECREASE_BALANCE_AND_SET_ACTIVITY, true);
//     }
// }
