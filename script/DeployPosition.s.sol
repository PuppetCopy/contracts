// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {GmxExecutionCallback} from "src/position/GmxExecutionCallback.sol";
import {MatchRule} from "src/position/MatchRule.sol";
import {MirrorPosition} from "src/position/MirrorPosition.sol";
import {IGmxExchangeRouter} from "src/position/interface/IGmxExchangeRouter.sol";
import {AllocationStore} from "src/shared/AllocationStore.sol";
import {Dictatorship} from "src/shared/Dictatorship.sol";
import {FeeMarketplace} from "src/shared/FeeMarketplace.sol";
import {FeeMarketplaceStore} from "src/shared/FeeMarketplaceStore.sol";
import {TokenRouter} from "src/shared/TokenRouter.sol";
import {TokenRouter} from "src/shared/TokenRouter.sol";
import {PuppetToken} from "src/tokenomics/PuppetToken.sol";
import {PuppetVoteToken} from "src/tokenomics/PuppetVoteToken.sol";

import {BaseScript} from "./BaseScript.s.sol";
import {Address} from "./Const.sol";

contract DeployPosition is BaseScript {
    Dictatorship dictator = Dictatorship(getDeployedAddress("Dictatorship"));

    function run() public {
        vm.startBroadcast(DEPLOYER_PRIVATE_KEY);
        deployContracts();
        vm.stopBroadcast();
    }

    function deployContracts() internal {
        PuppetToken puppetToken = PuppetToken(getDeployedAddress("PuppetToken"));
        TokenRouter tokenRouter = TokenRouter(getDeployedAddress("TokenRouter"));

        AllocationStore allocationStore = new AllocationStore(dictator, tokenRouter);
        MatchRule matchRule = new MatchRule(dictator, allocationStore, MirrorPosition(getNextCreateAddress(3)));
        FeeMarketplaceStore feeMarketplaceStore = new FeeMarketplaceStore(dictator, tokenRouter, puppetToken);
        FeeMarketplace feeMarketplace = new FeeMarketplace(dictator, tokenRouter, feeMarketplaceStore, puppetToken);
        MirrorPosition mirrorPosition = new MirrorPosition(dictator, allocationStore, matchRule, feeMarketplace);
        GmxExecutionCallback gmxCallbackHandler = new GmxExecutionCallback(dictator, mirrorPosition);

        // Config
        IERC20[] memory allowedTokenList = new IERC20[](2);
        allowedTokenList[0] = IERC20(Address.wnt);
        allowedTokenList[1] = IERC20(Address.usdc);
        uint[] memory tokenAllowanceCapAmountList = new uint[](2);
        tokenAllowanceCapAmountList[0] = 0.2e18;
        tokenAllowanceCapAmountList[1] = 500e30;

        uint[] memory tokenDustThresholdCapList = new uint[](2);
        tokenDustThresholdCapList[0] = 0.01e18;
        tokenDustThresholdCapList[1] = 1e6;

        // Configure contracts
        dictator.initContract(
            matchRule,
            abi.encode(
                MatchRule.Config({
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
                    tokenDustThresholdList: allowedTokenList,
                    tokenDustThresholdCapList: tokenDustThresholdCapList,
                    gmxExchangeRouter: IGmxExchangeRouter(Address.gmxExchangeRouter),
                    callbackHandler: address(mirrorPosition), // Self-callback for tests
                    gmxOrderVault: Address.gmxOrderVault,
                    referralCode: Address.referralCode,
                    increaseCallbackGasLimit: 2_000_000,
                    decreaseCallbackGasLimit: 2_000_000,
                    platformSettleFeeFactor: 0.1e30, // 10%
                    maxPuppetList: 20,
                    maxKeeperFeeToAllocationRatio: 0.1e30, // 10%
                    maxKeeperFeeToAdjustmentRatio: 0.05e30, // 5%
                    maxKeeperFeeToCollectDustRatio: 0.1e30 // 10%
                })
            )
        );

        dictator.setAccess(tokenRouter, address(allocationStore));
        dictator.setAccess(allocationStore, address(matchRule));
        dictator.setAccess(allocationStore, address(mirrorPosition));
        dictator.setAccess(allocationStore, address(feeMarketplace));

        // mirrorPosition permissions (owner for most actions in tests)
        dictator.setPermission(mirrorPosition, mirrorPosition.mirror.selector, Address.orderflowHandler);
        dictator.setPermission(mirrorPosition, mirrorPosition.adjust.selector, Address.orderflowHandler); // Added
            // adjust permission
        dictator.setPermission(mirrorPosition, mirrorPosition.settle.selector, Address.orderflowHandler);
        dictator.setPermission(mirrorPosition, mirrorPosition.collectDust.selector, Address.orderflowHandler);
        dictator.setPermission(
            mirrorPosition,
            mirrorPosition.initializeTraderActivityThrottle.selector,
            address(matchRule) // MatchRule initializes throttle
        );
        dictator.setPermission(mirrorPosition, mirrorPosition.execute.selector, address(gmxCallbackHandler));

        dictator.setPermission(feeMarketplace, feeMarketplace.deposit.selector, address(mirrorPosition));
        dictator.setPermission(feeMarketplace, feeMarketplace.acceptOffer.selector, getDeployedAddress("Router"));
        dictator.setPermission(feeMarketplace, feeMarketplace.setAskPrice.selector, Address.dao);
        dictator.setAccess(feeMarketplaceStore, address(feeMarketplace));
        dictator.setAccess(allocationStore, address(feeMarketplaceStore));
        dictator.setAccess(tokenRouter, address(feeMarketplaceStore));
        // feeMarketplace.setAskPrice(usdc, 100e18);

        // dictator.setPermission(matchRule, matchRule.setRule.selector, users.owner);
        // dictator.setPermission(matchRule, matchRule.deposit.selector, users.owner);
    }
}
