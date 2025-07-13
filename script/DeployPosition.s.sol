// // SPDX-License-Identifier: BUSL-1.1
// pragma solidity ^0.8.29;

// import {IGasFeeCallbackReceiver} from "@gmx/contracts/callback/IGasFeeCallbackReceiver.sol";
// import {IOrderCallbackReceiver} from "@gmx/contracts/callback/IOrderCallbackReceiver.sol";
// import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
// import {Proxy} from "@openzeppelin/contracts/proxy/Proxy.sol";
// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import {console} from "forge-std/src/console.sol";

// import {keeperRouter} from "src/keeperRouter.sol";
// import {RouterProxy} from "src/utils/RouterProxy.sol";
// import {Allocation} from "src/position/Allocation.sol";
// import {MatchingRule} from "src/position/MatchingRule.sol";
// import {MirrorPosition} from "src/position/MirrorPosition.sol";
// import {IGmxExchangeRouter} from "src/position/interface/IGmxExchangeRouter.sol";
// import {AllocationStore} from "src/shared/AllocationStore.sol";
// import {Dictatorship} from "src/shared/Dictatorship.sol";
// import {FeeMarketplace} from "src/shared/FeeMarketplace.sol";
// import {FeeMarketplaceStore} from "src/shared/FeeMarketplaceStore.sol";
// import {TokenRouter} from "src/shared/TokenRouter.sol";
// import {PuppetToken} from "src/tokenomics/PuppetToken.sol";
// import {PuppetVoteToken} from "src/tokenomics/PuppetVoteToken.sol";

// import {BaseScript} from "./BaseScript.s.sol";
// import {Const} from "./Const.sol";

// contract DeployPosition is BaseScript {
//     Dictatorship dictator = Dictatorship(getDeployedAddress("Dictatorship"));
//     PuppetToken puppetToken = PuppetToken(getDeployedAddress("PuppetToken"));
//     TokenRouter tokenRouter = TokenRouter(getDeployedAddress("TokenRouter"));
//     RouterProxy routerProxy = RouterProxy(payable(getDeployedAddress("RouterProxy")));

//     function run() public {
//         vm.startBroadcast(DEPLOYER_PRIVATE_KEY);
//         // deployContracts();
//         // setMirrorPositionConfig();
//         deployMirrorPosition(
//             AllocationStore(getDeployedAddress("AllocationStore")),
//             MatchingRule(getDeployedAddress("MatchingRule")),
//             FeeMarketplace(getDeployedAddress("FeeMarketplace"))
//         );

//         vm.stopBroadcast();
//     }

//     function deployContracts() internal {
//         AllocationStore allocationStore = new AllocationStore(dictator, tokenRouter);
//         Allocation allocation = new Allocation(
//             dictator,
//             allocationStore,
//             Allocation.Config({
//                 platformSettleFeeFactor: 0.01e30,
//                 maxKeeperFeeToCollectDustRatio: 0.1e30,
//                 maxPuppetList: 50
//             })
//         );

//         FeeMarketplaceStore feeMarketplaceStore = new FeeMarketplaceStore(dictator, tokenRouter, puppetToken);
//         FeeMarketplace feeMarketplace = new FeeMarketplace(
//             dictator,
//             puppetToken,
//             feeMarketplaceStore,
//             FeeMarketplace.Config({
//                 distributionTimeframe: 1 days,
//                 burnBasisPoints: 10000,
//                 feeDistributor: feeMarketplaceStore
//             })
//         );
//         MatchingRule matchingRule = new MatchingRule(
//             dictator,
//             allocationStore,
//             MatchingRule.Config({
//                 minExpiryDuration: 1 days,
//                 minAllowanceRate: 100,
//                 maxAllowanceRate: 10000,
//                 minActivityThrottle: 1 hours,
//                 maxActivityThrottle: 30 days
//             })
//         );

//         (MirrorPosition mirrorPosition, IERC20[] memory allowedTokenList) =
//             createMirrorPosition(allocationStore, matchingRule, feeMarketplace);

//         // Set allocation in MirrorPosition
//         mirrorPosition.setAllocation(allocation);

//         dictator.setPermission(tokenRouter, tokenRouter.transfer.selector, address(allocationStore));
//         dictator.setPermission(tokenRouter, tokenRouter.transfer.selector, address(feeMarketplaceStore));

//         dictator.setAccess(allocationStore, address(matchingRule));
//         dictator.setAccess(allocationStore, address(feeMarketplace));
//         dictator.setAccess(allocationStore, address(feeMarketplaceStore));
//         dictator.setAccess(allocationStore, address(allocation));
//         dictator.setAccess(feeMarketplaceStore, address(feeMarketplace));

//         dictator.setPermission(feeMarketplace, feeMarketplace.setAskPrice.selector, Const.dao);
//         dictator.setPermission(feeMarketplace, feeMarketplace.acceptOffer.selector, address(routerProxy));

//         dictator.setPermission(matchingRule, matchingRule.setRule.selector, address(routerProxy));
//         dictator.setPermission(matchingRule, matchingRule.deposit.selector, address(routerProxy));
//         dictator.setPermission(matchingRule, matchingRule.withdraw.selector, address(routerProxy));
//         dictator.setPermission(matchingRule, matchingRule.setTokenAllowanceList.selector, Const.dao);

//         // Configure contracts
//         dictator.initContract(matchingRule);
//         uint[] memory tokenAllowanceCapAmountList = new uint[](2);
//         tokenAllowanceCapAmountList[0] = 0.2e18;
//         tokenAllowanceCapAmountList[1] = 500e30;
//         matchingRule.setTokenAllowanceList(allowedTokenList, tokenAllowanceCapAmountList);

//         dictator.initContract(feeMarketplace);
//         feeMarketplace.setAskPrice(IERC20(Const.usdc), 100e18);

//         updateRouter(mirrorPosition, matchingRule, feeMarketplace, allocation);

//         console.log("Seeding MatchingRule with initial rules...");
//         Router(address(routerProxy)).setMatchingRule(
//             IERC20(Const.usdc),
//             DEPLOYER_ADDRESS,
//             MatchingRule.Rule({allowanceRate: 1000, throttleActivity: 1 hours, expiry: block.timestamp + 84 weeks})
//         );
//     }

//     function updateRouter(
//         MirrorPosition mirrorPosition,
//         MatchingRule matchingRule,
//         FeeMarketplace feeMarketplace,
//         Allocation allocation
//     ) public {
//         Router newRouter = new Router(mirrorPosition, matchingRule, feeMarketplace, allocation);
//         routerProxy.update(address(newRouter));
//         console.log("Router implementation updated to:", address(newRouter));
//     }

//     function createMirrorPosition(
//         AllocationStore allocationStore,
//         MatchingRule matchingRule,
//         FeeMarketplace feeMarketplace
//     ) public returns (MirrorPosition mirrorPosition, IERC20[] memory allowedTokenList) {
//         Allocation allocation = new Allocation(
//             dictator,
//             allocationStore,
//             Allocation.Config({
//                 platformSettleFeeFactor: 0.01e30,
//                 maxKeeperFeeToCollectDustRatio: 0.1e30,
//                 maxPuppetList: 50
//             })
//         );
//         allowedTokenList = new IERC20[](2);
//         allowedTokenList[0] = IERC20(Const.wnt);
//         allowedTokenList[1] = IERC20(Const.usdc);

//         GmxExecutionCallback gmxCallbackHandler = new GmxExecutionCallback(
//             dictator,
//             GmxExecutionCallback.Config({
//                 mirrorPosition: MirrorPosition(getNextCreateAddress()),
//                 refundExecutionFeeReceiver: Const.orderflowHandler
//             })
//         );

//         verifySelectorsMatch();

//         mirrorPosition = new MirrorPosition(
//             dictator,
//             allocationStore,
//             MirrorPosition.Config({
//                 gmxExchangeRouter: IGmxExchangeRouter(Const.gmxExchangeRouter),
//                 callbackHandler: address(gmxCallbackHandler),
//                 gmxOrderVault: Const.gmxOrderVault,
//                 referralCode: Const.referralCode,
//                 increaseCallbackGasLimit: 200_000,
//                 decreaseCallbackGasLimit: 200_000,
//                 maxPuppetList: 50,
//                 maxKeeperFeeToAllocationRatio: 0.1e30,
//                 maxKeeperFeeToAdjustmentRatio: 0.1e30
//             })
//         );
//         dictator.initContract(mirrorPosition);

//         dictator.setPermission(
//             gmxCallbackHandler, gmxCallbackHandler.afterOrderExecution.selector, Const.gmxLiquidationHandler
//         );
//         dictator.setPermission(gmxCallbackHandler, gmxCallbackHandler.afterOrderExecution.selector,
// Const.gmxAdlHandler);
//         dictator.setPermission(
//             gmxCallbackHandler, gmxCallbackHandler.afterOrderExecution.selector, Const.gmxOrderHandler
//         );
//         dictator.setPermission(
//             gmxCallbackHandler, gmxCallbackHandler.afterOrderCancellation.selector, Const.gmxOrderHandler
//         );
//         dictator.setPermission(gmxCallbackHandler, gmxCallbackHandler.afterOrderFrozen.selector,
// Const.gmxOrderHandler);
//         dictator.initContract(gmxCallbackHandler);

//         dictator.setPermission(mirrorPosition, mirrorPosition.execute.selector, address(gmxCallbackHandler));
//         dictator.setPermission(mirrorPosition, mirrorPosition.liquidate.selector, address(gmxCallbackHandler));

//         dictator.setPermission(mirrorPosition, mirrorPosition.requestMirror.selector, Const.orderflowHandler);
//         dictator.setPermission(mirrorPosition, mirrorPosition.requestAdjust.selector, Const.orderflowHandler);

//         dictator.setPermission(allocation, allocation.initializeTraderActivityThrottle.selector,
// address(matchingRule));
//         dictator.setPermission(allocation, allocation.createAllocation.selector, address(mirrorPosition));
//         dictator.setPermission(allocation, allocation.settle.selector, Const.orderflowHandler);
//         dictator.setPermission(allocation, allocation.collectDust.selector, Const.orderflowHandler);
//         dictator.setPermission(allocation, allocation.setTokenDustThresholdList.selector, Const.dao);
//         dictator.setPermission(allocation, allocation.transferOut.selector, address(mirrorPosition));
//         dictator.initContract(allocation);
//         uint[] memory tokenDustThresholdCapList = new uint[](2);
//         tokenDustThresholdCapList[0] = 0.01e18;
//         tokenDustThresholdCapList[1] = 1e6;
//         allocation.setTokenDustThresholdList(allowedTokenList, tokenDustThresholdCapList);

//         dictator.setAccess(allocationStore, address(mirrorPosition));
//         dictator.setPermission(feeMarketplace, feeMarketplace.deposit.selector, address(mirrorPosition));

//         // return mirrorPosition;
//         return (mirrorPosition, allowedTokenList);
//     }

//     function deployMirrorPosition(
//         AllocationStore allocationStore,
//         MatchingRule matchingRule,
//         FeeMarketplace feeMarketplace
//     ) public returns (MirrorPosition mirrorPosition, IERC20[] memory allowedTokenList) {
//         (mirrorPosition, allowedTokenList) = createMirrorPosition(allocationStore, matchingRule, feeMarketplace);

//         updateRouter(mirrorPosition, matchingRule, feeMarketplace, Allocation(getDeployedAddress("Allocation")));
//     }

//     function setMirrorPositionConfig() public {
//         MirrorPosition mirrorPosition = MirrorPosition(getDeployedAddress("MirrorPosition"));
//         GmxExecutionCallback gmxCallbackHandler = GmxExecutionCallback(getDeployedAddress("GmxExecutionCallback"));

//         dictator.setConfig(
//             mirrorPosition,
//             abi.encode(
//                 MirrorPosition.Config({
//                     gmxExchangeRouter: IGmxExchangeRouter(Const.gmxExchangeRouter),
//                     callbackHandler: address(gmxCallbackHandler),
//                     gmxOrderVault: Const.gmxOrderVault,
//                     referralCode: Const.referralCode,
//                 increaseCallbackGasLimit: 2e6,
//                 decreaseCallbackGasLimit: 2e6,
//                     maxPuppetList: 100,
//                     maxKeeperFeeToAllocationRatio: 0.1e30,
//                     maxKeeperFeeToAdjustmentRatio: 0.1e30
//                 })
//             )
//         );
//     }

//     function verifySelectorsMatch() public {
//         console.log("\n=== Verifying Selector Compatibility ===");

//         GmxExecutionCallback tempCallback = new GmxExecutionCallback(
//             dictator,
//             GmxExecutionCallback.Config({
//                 mirrorPosition: MirrorPosition(address(0xDeaDbeefdEAdbeefdEadbEEFdeadbeEFdEaDbeeF)),
//                 refundExecutionFeeReceiver: address(0)
//             })
//         );

//         console.log(
//             "Matching afterOrderExecution? ",
//             IOrderCallbackReceiver.afterOrderExecution.selector == tempCallback.afterOrderExecution.selector
//                 ? "YES"
//                 : "NO"
//         );
//         console.log(
//             "Matching afterOrderCancellation? ",
//             IOrderCallbackReceiver.afterOrderCancellation.selector == tempCallback.afterOrderCancellation.selector
//                 ? "YES"
//                 : "NO"
//         );
//         console.log(
//             "Matching afterOrderFrozen? ",
//             IOrderCallbackReceiver.afterOrderFrozen.selector == tempCallback.afterOrderFrozen.selector ? "YES" : "NO"
//         );
//         console.log(
//             "Matching refundExecutionFee? ",
//             IGasFeeCallbackReceiver.refundExecutionFee.selector == tempCallback.refundExecutionFee.selector
//                 ? "YES"
//                 : "NO"
//         );
//     }
// }
