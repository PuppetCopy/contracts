// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {PositionRouter} from "src/PositionRouter.sol";
import {PuppetRouter} from "src/PuppetRouter.sol";
import {RewardRouter} from "src/RewardRouter.sol";

import {ExecuteDecreasePositionLogic} from "src/position/ExecuteDecreasePositionLogic.sol";
import {ExecuteIncreasePositionLogic} from "src/position/ExecuteIncreasePositionLogic.sol";
import {ExecuteRevertedAdjustmentLogic} from "src/position/ExecuteRevertedAdjustmentLogic.sol";
import {RequestPositionLogic} from "src/position/RequestPositionLogic.sol";
import {IGmxExchangeRouter} from "src/position/interface/IGmxExchangeRouter.sol";
import {PositionStore} from "src/position/store/PositionStore.sol";
import {PositionStore} from "src/position/store/PositionStore.sol";
import {PuppetLogic} from "src/puppet/PuppetLogic.sol";
import {PuppetStore} from "src/puppet/store/PuppetStore.sol";
import {Dictator} from "src/shared/Dictator.sol";
import {Router} from "src/shared/Router.sol";
import {Router} from "src/shared/Router.sol";
import {ContributeLogic} from "src/tokenomics/ContributeLogic.sol";
import {PuppetToken} from "src/tokenomics/PuppetToken.sol";
import {PuppetVoteToken} from "src/tokenomics/PuppetVoteToken.sol";
import {RewardLogic} from "src/tokenomics/RewardLogic.sol";
import {VotingEscrowLogic} from "src/tokenomics/VotingEscrowLogic.sol";
import {ContributeStore} from "src/tokenomics/store/ContributeStore.sol";
import {EventEmitter} from "src/utils/EventEmitter.sol";

import {BaseScript} from "./BaseScript.s.sol";
import {Address} from "./Const.sol";

contract DeployTokenomics is BaseScript {
    Dictator dictator = Dictator(Address.Dictator);
    EventEmitter eventEmitter = EventEmitter(Address.EventEmitter);
    PuppetToken puppetToken = PuppetToken(Address.PuppetToken);
    PuppetVoteToken vPuppetToken = PuppetVoteToken(Address.PuppetVoteToken);
    Router router = Router(Address.Router);

    function run() public {
        vm.startBroadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));
        // deployImmutables();

        deployPuppetLogic();
        deployPositionLogic();

        vm.stopBroadcast();
    }

    function deployImmutables() internal {
        PuppetStore puppetStore = new PuppetStore(dictator, router);
        dictator.setPermission(router, router.transfer.selector, address(puppetStore));
        PositionStore positionStore = new PositionStore(dictator, router);
        dictator.setPermission(router, router.transfer.selector, address(positionStore));

        PuppetRouter puppetRouter = new PuppetRouter(dictator, eventEmitter);
        dictator.setAccess(eventEmitter, address(puppetRouter));

        PositionRouter positionRouter = new PositionRouter(dictator, eventEmitter, positionStore);
        dictator.setAccess(eventEmitter, address(positionRouter));
    }

    function deployPuppetLogic() internal {
        PuppetStore puppetStore = PuppetStore(Address.PuppetStore);
        PuppetRouter puppetRouter = PuppetRouter(Address.PuppetRouter);

        PuppetLogic puppetLogic = new PuppetLogic(dictator, eventEmitter, puppetStore);
        dictator.setAccess(eventEmitter, address(puppetLogic));
        dictator.setAccess(puppetStore, address(puppetLogic));
        dictator.setPermission(puppetLogic, puppetLogic.setConfig.selector, Address.dao);
        IERC20[] memory tokenAllowanceCapList = new IERC20[](2);
        tokenAllowanceCapList[0] = IERC20(Address.wnt);
        tokenAllowanceCapList[1] = IERC20(Address.usdc);
        uint[] memory tokenAllowanceCapAmountList = new uint[](2);
        tokenAllowanceCapAmountList[0] = 0.2e18;
        tokenAllowanceCapAmountList[1] = 500e30;

        puppetLogic.setConfig(
            PuppetLogic.Config({
                minExpiryDuration: 1 days,
                minAllowanceRate: 1000,
                maxAllowanceRate: 10000,
                tokenAllowanceList: tokenAllowanceCapList,
                tokenAllowanceAmountList: tokenAllowanceCapAmountList
            })
        );

        dictator.setPermission(puppetLogic, puppetLogic.deposit.selector, address(puppetRouter));
        dictator.setPermission(puppetLogic, puppetLogic.setRule.selector, address(puppetRouter));
        dictator.setPermission(puppetLogic, puppetLogic.setRuleList.selector, address(puppetRouter));

        dictator.setPermission(puppetRouter, puppetRouter.setConfig.selector, Address.dao);
        puppetRouter.setConfig(PuppetRouter.Config({logic: puppetLogic}));
    }

    function deployPositionLogic() internal {
        PuppetStore puppetStore = PuppetStore(Address.PuppetStore);
        PositionStore positionStore = PositionStore(Address.PositionStore);
        ContributeStore contributeStore = ContributeStore(Address.ContributeStore);
        PositionRouter positionRouter = PositionRouter(Address.PositionRouter);

        RequestPositionLogic requestIncreaseLogic =
            new RequestPositionLogic(dictator, eventEmitter, puppetStore, positionStore);
        dictator.setAccess(eventEmitter, address(requestIncreaseLogic));
        dictator.setAccess(puppetStore, address(requestIncreaseLogic));
        dictator.setAccess(positionStore, address(requestIncreaseLogic));

        ExecuteIncreasePositionLogic executeIncreaseLogic =
            new ExecuteIncreasePositionLogic(dictator, eventEmitter, positionStore);
        dictator.setAccess(eventEmitter, address(executeIncreaseLogic));
        dictator.setAccess(positionStore, address(executeIncreaseLogic));
        ExecuteDecreasePositionLogic executeDecreaseLogic =
            new ExecuteDecreasePositionLogic(dictator, eventEmitter, contributeStore, puppetStore, positionStore);
        dictator.setAccess(eventEmitter, address(executeDecreaseLogic));
        dictator.setAccess(positionStore, address(executeDecreaseLogic));
        dictator.setAccess(contributeStore, address(executeDecreaseLogic));

        ExecuteRevertedAdjustmentLogic executeRevertedAdjustment =
            new ExecuteRevertedAdjustmentLogic(dictator, eventEmitter);
        dictator.setAccess(eventEmitter, address(executeRevertedAdjustment));

        dictator.setPermission(positionRouter, positionRouter.afterOrderExecution.selector, Address.gmxOrderHandler);
        dictator.setPermission(positionRouter, positionRouter.afterOrderCancellation.selector, Address.gmxOrderHandler);
        dictator.setPermission(positionRouter, positionRouter.afterOrderFrozen.selector, Address.gmxOrderHandler);

        dictator.setPermission(requestIncreaseLogic, requestIncreaseLogic.setConfig.selector, Address.dao);
        requestIncreaseLogic.setConfig(
            RequestPositionLogic.Config({
                gmxExchangeRouter: IGmxExchangeRouter(Address.gmxExchangeRouter),
                callbackHandler: Address.PositionRouter,
                gmxOrderReciever: Address.PositionStore,
                gmxOrderVault: Address.gmxOrderVault,
                referralCode: Address.referralCode,
                callbackGasLimit: 2_000_000,
                limitPuppetList: 60,
                minimumMatchAmount: 100e30
            })
        );
        dictator.setPermission(executeDecreaseLogic, executeDecreaseLogic.setConfig.selector, Address.dao);
        executeDecreaseLogic.setConfig(
            ExecuteDecreasePositionLogic.Config({
                gmxOrderReciever: address(positionStore),
                performanceFeeRate: 0.1e30, // 10%
                traderPerformanceFeeShare: 0.5e30 // shared between trader and platform
            })
        );
        dictator.setPermission(positionRouter, positionRouter.setConfig.selector, Address.dao);
        positionRouter.setConfig(
            PositionRouter.Config({
                executeIncrease: executeIncreaseLogic,
                executeDecrease: executeDecreaseLogic,
                executeRevertedAdjustment: executeRevertedAdjustment
            })
        );
        dictator.setPermission(requestIncreaseLogic, requestIncreaseLogic.orderMirrorPosition.selector, Address.dao);
    }

    function deployRewardRouter(
        ContributeLogic contributeLogic,
        RewardLogic rewardLogic,
        VotingEscrowLogic veLogic
    ) internal returns (RewardRouter rewardRouter) {
        dictator.setAccess(eventEmitter, getNextCreateAddress());
        rewardRouter = new RewardRouter(
            dictator,
            eventEmitter,
            RewardRouter.Config({contributeLogic: contributeLogic, rewardLogic: rewardLogic, veLogic: veLogic})
        );
        dictator.setPermission(rewardRouter, rewardRouter.setConfig.selector, Address.dao);

        dictator.setPermission(contributeLogic, contributeLogic.buyback.selector, address(rewardRouter));
        dictator.setPermission(contributeLogic, contributeLogic.claim.selector, address(rewardRouter));

        dictator.setPermission(veLogic, veLogic.lock.selector, address(rewardRouter));
        dictator.setPermission(veLogic, veLogic.vest.selector, address(rewardRouter));
        dictator.setPermission(veLogic, veLogic.claim.selector, address(rewardRouter));

        dictator.setPermission(rewardLogic, rewardLogic.claim.selector, address(rewardRouter));
        dictator.setPermission(rewardLogic, rewardLogic.userDistribute.selector, address(rewardRouter));
        dictator.setPermission(rewardLogic, rewardLogic.distribute.selector, address(rewardRouter));
    }
}
