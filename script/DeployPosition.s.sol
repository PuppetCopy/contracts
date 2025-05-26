// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import {Proxy} from "@openzeppelin/contracts/proxy/Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {console} from "forge-std/src/console.sol";

import {Router} from "src/Router.sol";
import {RouterProxy} from "src/RouterProxy.sol";
import {GmxExecutionCallback} from "src/position/GmxExecutionCallback.sol";
import {MatchingRule} from "src/position/MatchingRule.sol";
import {MirrorPosition} from "src/position/MirrorPosition.sol";
import {IGmxExchangeRouter} from "src/position/interface/IGmxExchangeRouter.sol";
import {AllocationStore} from "src/shared/AllocationStore.sol";
import {Dictatorship} from "src/shared/Dictatorship.sol";
import {FeeMarketplace} from "src/shared/FeeMarketplace.sol";
import {FeeMarketplaceStore} from "src/shared/FeeMarketplaceStore.sol";
import {TokenRouter} from "src/shared/TokenRouter.sol";
import {PuppetToken} from "src/tokenomics/PuppetToken.sol";
import {PuppetVoteToken} from "src/tokenomics/PuppetVoteToken.sol";

import {BaseScript} from "./BaseScript.s.sol";
import {Const} from "./Const.sol";

contract DeployPosition is BaseScript {
    Dictatorship dictator = Dictatorship(getDeployedAddress("Dictatorship"));
    PuppetToken puppetToken = PuppetToken(getDeployedAddress("PuppetToken"));
    TokenRouter tokenRouter = TokenRouter(getDeployedAddress("TokenRouter"));
    RouterProxy routerProxy = RouterProxy(payable(getDeployedAddress("RouterProxy")));

    function run() public {
        vm.startBroadcast(DEPLOYER_PRIVATE_KEY);
        deployContracts();
        vm.stopBroadcast();
    }

    function deployContracts() internal {
        AllocationStore allocationStore = new AllocationStore(dictator, tokenRouter);
        FeeMarketplaceStore feeMarketplaceStore = new FeeMarketplaceStore(dictator, tokenRouter, puppetToken);
        FeeMarketplace feeMarketplace = new FeeMarketplace(dictator, feeMarketplaceStore, puppetToken);
        MirrorPosition mirrorPosition =
            new MirrorPosition(dictator, allocationStore, MatchingRule(getNextCreateAddress(2)), feeMarketplace);

        MatchingRule matchingRule = new MatchingRule(dictator, allocationStore, mirrorPosition);
        GmxExecutionCallback gmxCallbackHandler = new GmxExecutionCallback(dictator, mirrorPosition);

        require(
            address(mirrorPosition.matchingRule()) == address(matchingRule),
            "MirrorPosition not initialized correctly with MatchingRule"
        );

        dictator.setAccess(tokenRouter, address(allocationStore));
        dictator.setAccess(tokenRouter, address(feeMarketplaceStore));

        dictator.setAccess(allocationStore, address(matchingRule));
        dictator.setAccess(allocationStore, address(mirrorPosition));
        dictator.setAccess(allocationStore, address(feeMarketplace));
        dictator.setAccess(allocationStore, address(feeMarketplaceStore));
        dictator.setAccess(feeMarketplaceStore, address(feeMarketplace));

        // mirrorPosition permissions (owner for most actions in tests)
        dictator.setPermission(mirrorPosition, mirrorPosition.requestMirror.selector, Const.orderflowHandler);
        dictator.setPermission(mirrorPosition, mirrorPosition.requestAdjust.selector, Const.orderflowHandler);
        dictator.setPermission(mirrorPosition, mirrorPosition.settle.selector, Const.orderflowHandler);
        dictator.setPermission(mirrorPosition, mirrorPosition.collectDust.selector, Const.orderflowHandler);
        dictator.setPermission(mirrorPosition, mirrorPosition.setTokenDustThresholdList.selector, Const.dao);
        dictator.setPermission(
            mirrorPosition, //
            mirrorPosition.initializeTraderActivityThrottle.selector,
            address(matchingRule)
        );
        dictator.setPermission(mirrorPosition, mirrorPosition.execute.selector, address(gmxCallbackHandler));
        dictator.setPermission(mirrorPosition, mirrorPosition.liquidate.selector, address(gmxCallbackHandler));

        dictator.setPermission(feeMarketplace, feeMarketplace.deposit.selector, address(mirrorPosition));
        dictator.setPermission(feeMarketplace, feeMarketplace.setAskPrice.selector, Const.dao);
        dictator.setPermission(feeMarketplace, feeMarketplace.acceptOffer.selector, address(routerProxy));

        dictator.setPermission(matchingRule, matchingRule.setRule.selector, address(routerProxy));
        dictator.setPermission(matchingRule, matchingRule.deposit.selector, address(routerProxy));
        dictator.setPermission(matchingRule, matchingRule.setTokenAllowanceList.selector, Const.dao);

        dictator.setPermission(
            gmxCallbackHandler, gmxCallbackHandler.afterOrderExecution.selector, Const.gmxOrderHandler
        );
        dictator.setPermission(
            gmxCallbackHandler, gmxCallbackHandler.afterOrderExecution.selector, Const.gmxLiquidationHandler
        );
        dictator.setPermission(gmxCallbackHandler, gmxCallbackHandler.afterOrderExecution.selector, Const.gmxAdlHandler);
        dictator.setPermission(
            gmxCallbackHandler, gmxCallbackHandler.afterOrderCancellation.selector, Const.gmxOrderHandler
        );
        dictator.setPermission(gmxCallbackHandler, gmxCallbackHandler.afterOrderFrozen.selector, Const.gmxOrderHandler);

        // Configuration - same as before
        IERC20[] memory allowedTokenList = new IERC20[](2);
        allowedTokenList[0] = IERC20(Const.wnt);
        allowedTokenList[1] = IERC20(Const.usdc);

        // Configure contracts
        dictator.initContract(
            matchingRule,
            abi.encode(
                MatchingRule.Config({
                    minExpiryDuration: 1 days,
                    minAllowanceRate: 100,
                    maxAllowanceRate: 10000,
                    minActivityThrottle: 1 hours,
                    maxActivityThrottle: 30 days
                })
            )
        );
        uint[] memory tokenAllowanceCapAmountList = new uint[](2);
        tokenAllowanceCapAmountList[0] = 0.2e18;
        tokenAllowanceCapAmountList[1] = 500e30;
        matchingRule.setTokenAllowanceList(allowedTokenList, tokenAllowanceCapAmountList);

        dictator.initContract(
            feeMarketplace,
            abi.encode(
                FeeMarketplace.Config({
                    distributionTimeframe: 1 days,
                    burnBasisPoints: 10000,
                    feeDistributor: feeMarketplaceStore
                })
            )
        );
        feeMarketplace.setAskPrice(IERC20(Const.usdc), 100e18);

        dictator.initContract(
            mirrorPosition,
            abi.encode(
                MirrorPosition.Config({
                    gmxExchangeRouter: IGmxExchangeRouter(Const.gmxExchangeRouter),
                    callbackHandler: address(gmxCallbackHandler),
                    gmxOrderVault: Const.gmxOrderVault,
                    referralCode: Const.referralCode,
                    increaseCallbackGasLimit: 2_000_000,
                    decreaseCallbackGasLimit: 2_000_000,
                    platformSettleFeeFactor: 0.1e30,
                    maxPuppetList: 50,
                    maxKeeperFeeToAllocationRatio: 0.1e30,
                    maxKeeperFeeToAdjustmentRatio: 0.05e30,
                    maxKeeperFeeToCollectDustRatio: 0.1e30
                })
            )
        );
        uint[] memory tokenDustThresholdCapList = new uint[](2);
        tokenDustThresholdCapList[0] = 0.01e18;
        tokenDustThresholdCapList[1] = 1e6;
        mirrorPosition.setTokenDustThresholdList(allowedTokenList, tokenDustThresholdCapList);

        // Deploy new Router implementation
        Router newRouter = new Router(matchingRule, feeMarketplace);

        // Update proxy to point to new implementation
        routerProxy.update(address(newRouter));

        console.log("Router implementation deployed at:", address(newRouter));

        console.log("Seeding MatchingRule with initial rules...");
        matchingRule.setRule(
            IERC20(Const.usdc),
            DEPLOYER_ADDRESS,
            DEPLOYER_ADDRESS,
            MatchingRule.Rule({
                allowanceRate: 1000, // Example value
                throttleActivity: 500, // Example value
                expiry: block.timestamp + 30 days // Example expiry
            })
        );
    }
}

contract MirrorPositionProxy is Proxy {
    constructor(address implementation, bytes memory _data) payable {
        ERC1967Utils.upgradeToAndCall(implementation, _data);
    }

    function _implementation() internal view virtual override returns (address) {
        return ERC1967Utils.getImplementation();
    }
}
