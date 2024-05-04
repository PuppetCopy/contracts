// // SPDX-License-Identifier: BUSL-1.1
// pragma solidity 0.8.24;

// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import {PRBTest} from "@prb/test/src/PRBTest.sol";
// import {StdUtils} from "forge-std/src/StdUtils.sol";

// import {IWNT} from "src/utils/interfaces/IWNT.sol";

// import {Dictator} from "src/shared/Dictator.sol";
// import {Router} from "src/shared/Router.sol";

// import {PuppetRouter} from "src/puppet/PuppetRouter.sol";
// import {PuppetStore} from "src/puppet/store/PuppetStore.sol";
// import {PuppetLogic} from "src/puppet/logic/PuppetLogic.sol";

// import {StoreController} from "./../src/shared/store/StoreController.sol";

// import {Address, Role} from "script/Const.sol";

// contract DeployPuppetRouter is PRBTest, StdUtils {
//     function run() public {
//         vm.startBroadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));
//         deployContracts();
//         vm.stopBroadcast();
//     }

//     function deployContracts() internal {
//         IERC20 usdc = IERC20(Address.usdc);
//         IWNT wnt = IWNT(Address.wnt);

//         Dictator dictator = Dictator(Address.Dictator);
//         Router router = Router(Address.Router);

//         IERC20[] memory _tokenAllowanceCapList = new IERC20[](2);
//         _tokenAllowanceCapList[0] = wnt;
//         _tokenAllowanceCapList[1] = usdc;

//         uint[] memory _tokenAllowanceCapAmountList = new uint[](2);
//         _tokenAllowanceCapAmountList[0] = 0.2e18;
//         _tokenAllowanceCapAmountList[1] = 500e30;

//         address puppetRouterAddress = computeCreateAddress(
//             vm.envAddress("DEPLOYER_ADDRESS"), //
//             vm.getNonce(vm.envAddress("DEPLOYER_ADDRESS")) + 1
//         );

//         StoreController.SetterConfig[] memory setterList = new StoreController.SetterConfig[](1);
//         setterList[0] = StoreController.SetterConfig(puppetRouterAddress, true);

//         PuppetStore puppetStore = new PuppetStore(dictator, router, _tokenAllowanceCapList, _tokenAllowanceCapAmountList);
//         dictator.setUserRole(address(puppetStore), Role.TOKEN_TRANSFER, true);

//         PuppetRouter puppetRouter = new PuppetRouter(
//             dictator,
//             puppetStore,
//             PuppetRouter.CallConfig({
//                 setRule: PuppetLogic.CallSetRuleConfig({
//                     router: router, //
//                     minExpiryDuration: 0,
//                     minAllowanceRate: 100,
//                     maxAllowanceRate: 5000
//                 })
//             })
//         );

//     }
// }
