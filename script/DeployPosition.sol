// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {GmxExecutionCallback} from "contracts/src/position/GmxExecutionCallback.sol";
import {MatchingRule} from "contracts/src/position/MatchingRule.sol";
import {MirrorPosition} from "contracts/src/position/MirrorPosition.sol";
import {IGmxExchangeRouter} from "contracts/src/position/interface/IGmxExchangeRouter.sol";
import {AllocationStore} from "contracts/src/shared/AllocationStore.sol";
import {Dictatorship} from "contracts/src/shared/Dictatorship.sol";
import {FeeMarketplace} from "contracts/src/shared/FeeMarketplace.sol";
import {FeeMarketplaceStore} from "contracts/src/shared/FeeMarketplaceStore.sol";
import {TokenRouter} from "contracts/src/shared/TokenRouter.sol";
import {TokenRouter} from "contracts/src/shared/TokenRouter.sol";
import {PuppetToken} from "contracts/src/tokenomics/PuppetToken.sol";
import {PuppetVoteToken} from "contracts/src/tokenomics/PuppetVoteToken.sol";
import {RouterProxy} from "contracts/src/RouterProxy.sol";
import {Router} from "contracts/src/Router.sol";

import {BaseScript} from "./BaseScript.s.sol";
import {Const} from "./Const.sol";

contract DeployPosition is BaseScript {
    function run() public {
        vm.startBroadcast(DEPLOYER_PRIVATE_KEY);
        deployContracts();
        vm.stopBroadcast();
    }

    function deployContracts() internal {
        Dictatorship dictator = Dictatorship(getDeployedAddress("Dictatorship"));
        PuppetToken puppetToken = PuppetToken(getDeployedAddress("PuppetToken"));
        TokenRouter tokenRouter = TokenRouter(getDeployedAddress("TokenRouter"));

        AllocationStore allocationStore = new AllocationStore(dictator, tokenRouter);
        address nextMirrorPositionAddress = getNextCreateAddress(3);
        MatchingRule matchingRule = new MatchingRule(dictator, allocationStore, MirrorPosition(nextMirrorPositionAddress));
        FeeMarketplaceStore feeMarketplaceStore = new FeeMarketplaceStore(dictator, tokenRouter, puppetToken);
        FeeMarketplace feeMarketplace = new FeeMarketplace(dictator, tokenRouter, feeMarketplaceStore, puppetToken);
        MirrorPosition mirrorPosition = new MirrorPosition(dictator, allocationStore, matchingRule, feeMarketplace);

        dictator.setAccess(tokenRouter, address(allocationStore));
        dictator.setAccess(allocationStore, address(matchingRule));
        dictator.setAccess(allocationStore, address(mirrorPosition));
        dictator.setAccess(allocationStore, address(feeMarketplace));

        // mirrorPosition permissions (owner for most actions in tests)
        dictator.setPermission(mirrorPosition, mirrorPosition.mirror.selector, Const.orderflowHandler);
        dictator.setPermission(mirrorPosition, mirrorPosition.adjust.selector, Const.orderflowHandler);
        dictator.setPermission(mirrorPosition, mirrorPosition.settle.selector, Const.orderflowHandler);
        dictator.setPermission(mirrorPosition, mirrorPosition.collectDust.selector, Const.orderflowHandler);
        dictator.setPermission(mirrorPosition, mirrorPosition.setTokenDustThreshold.selector, Const.orderflowHandler);
        dictator.setPermission(
            mirrorPosition,
            mirrorPosition.initializeTraderActivityThrottle.selector,
            address(matchingRule) // MatchingRule initializes throttle
        );

        dictator.setPermission(feeMarketplace, feeMarketplace.deposit.selector, address(mirrorPosition));
        dictator.setPermission(feeMarketplace, feeMarketplace.acceptOffer.selector, getDeployedAddress("Router"));
        dictator.setPermission(feeMarketplace, feeMarketplace.setAskPrice.selector, Const.dao);
        dictator.setAccess(feeMarketplaceStore, address(feeMarketplace));
        dictator.setAccess(allocationStore, address(feeMarketplaceStore));
        dictator.setAccess(tokenRouter, address(feeMarketplaceStore));

        // external contract integration
        require(
            address(mirrorPosition) == nextMirrorPositionAddress,
            "MirrorPosition address mismatch"
        );
        GmxExecutionCallback gmxCallbackHandler = new GmxExecutionCallback(dictator, mirrorPosition);
        dictator.setPermission(mirrorPosition, mirrorPosition.execute.selector, address(gmxCallbackHandler));
        dictator.setPermission(mirrorPosition, mirrorPosition.liquidate.selector, address(gmxCallbackHandler));


        // Config
        IERC20[] memory allowedTokenList = new IERC20[](2);
        allowedTokenList[0] = IERC20(Const.wnt);
        allowedTokenList[1] = IERC20(Const.usdc);
        uint[] memory tokenAllowanceCapAmountList = new uint[](2);
        tokenAllowanceCapAmountList[0] = 0.2e18;
        tokenAllowanceCapAmountList[1] = 500e30;

        uint[] memory tokenDustThresholdCapList = new uint[](2);
        tokenDustThresholdCapList[0] = 0.01e18;
        tokenDustThresholdCapList[1] = 1e6;

        // Configure contracts
        dictator.initContract(
            matchingRule,
            abi.encode(
                MatchingRule.Config({
                    minExpiryDuration: 1 days,
                    minAllowanceRate: 100, // 1 basis points = 1%
                    maxAllowanceRate: 10000, // 100%
                    minActivityThrottle: 1 hours,
                    maxActivityThrottle: 30 days,
                    tokenAllowanceList: allowedTokenList,
                    tokenAllowanceCapList: tokenAllowanceCapAmountList
                })
            )
        );

        dictator.initContract(
            feeMarketplace,
            abi.encode(
                FeeMarketplace.Config({
                    distributionTimeframe: 1 days,
                    burnBasisPoints: 10000,
                    feeDistributor: FeeMarketplaceStore(address(0))
                })
            )
        );

        dictator.initContract(
            mirrorPosition,
            abi.encode(
                MirrorPosition.Config({
                    gmxExchangeRouter: IGmxExchangeRouter(Const.gmxExchangeRouter),
                    callbackHandler: address(mirrorPosition), // Self-callback for tests
                    gmxOrderVault: Const.gmxOrderVault,
                    referralCode: Const.referralCode,
                    increaseCallbackGasLimit: 2_000_000,
                    decreaseCallbackGasLimit: 2_000_000,
                    platformSettleFeeFactor: 0.1e30, // 10%
                    maxPuppetList: 50,
                    maxKeeperFeeToAllocationRatio: 0.1e30, // 10%
                    maxKeeperFeeToAdjustmentRatio: 0.05e30, // 5%
                    maxKeeperFeeToCollectDustRatio: 0.1e30 // 10%
                })
            )
        );

        mirrorPosition.setTokenDustThreshold(allowedTokenList, tokenDustThresholdCapList);
        feeMarketplace.setAskPrice(IERC20(Const.usdc), 100e18);


        // Set up Router
        RouterProxy routerProxy = RouterProxy(payable(getDeployedAddress("RouterProxy")));

        dictator.setPermission(matchingRule, matchingRule.setRule.selector, address(routerProxy));
        dictator.setPermission(matchingRule, matchingRule.deposit.selector, address(routerProxy));
        dictator.setPermission(feeMarketplace, feeMarketplace.acceptOffer.selector, address(routerProxy));

        dictator.setAccess(routerProxy, Const.dao);
        routerProxy.update(
            address(
                new Router(
                    matchingRule, //
                    feeMarketplace
                )
            )
        );
    }
}
