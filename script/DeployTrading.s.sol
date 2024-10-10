// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {PositionRouter} from "src/PositionRouter.sol";
import {PuppetRouter} from "src/PuppetRouter.sol";

import {AllocationLogic} from "src/position/AllocationLogic.sol";
import {ExecutionLogic} from "src/position/ExecutionLogic.sol";

import {RequestLogic} from "src/position/RequestLogic.sol";
import {UnhandledCallbackLogic} from "src/position/UnhandledCallbackLogic.sol";
import {IGmxDatastore} from "src/position/interface/IGmxDatastore.sol";
import {IGmxExchangeRouter} from "src/position/interface/IGmxExchangeRouter.sol";
import {MirrorPositionStore} from "src/position/store/MirrorPositionStore.sol";
import {MirrorPositionStore} from "src/position/store/MirrorPositionStore.sol";
import {PuppetLogic} from "src/puppet/PuppetLogic.sol";
import {PuppetStore} from "src/puppet/store/PuppetStore.sol";
import {Dictator} from "src/shared/Dictator.sol";
import {Router} from "src/shared/Router.sol";
import {Router} from "src/shared/Router.sol";
import {PuppetToken} from "src/tokenomics/PuppetToken.sol";
import {PuppetVoteToken} from "src/tokenomics/PuppetVoteToken.sol";
import {ContributeStore} from "src/tokenomics/store/ContributeStore.sol";
import {EventEmitter} from "src/utils/EventEmitter.sol";

import {BaseScript} from "./BaseScript.s.sol";
import {Address} from "./Const.sol";

contract DeployTrading is BaseScript {
    Dictator dictator = Dictator(Address.Dictator);
    EventEmitter eventEmitter = EventEmitter(Address.EventEmitter);
    PuppetToken puppetToken = PuppetToken(Address.PuppetToken);
    PuppetVoteToken vPuppetToken = PuppetVoteToken(Address.PuppetVoteToken);
    Router router = Router(Address.Router);

    function run() public {
        vm.startBroadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));
        // deployImmutables();

        // deployPuppetLogic();
        deployPositionLogic();

        vm.stopBroadcast();
    }

    function deployImmutables() internal {
        PuppetStore puppetStore = new PuppetStore(dictator, router);
        dictator.setPermission(router, router.transfer.selector, address(puppetStore));
        MirrorPositionStore positionStore = new MirrorPositionStore(dictator, router);
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
                minAllowanceRate: 100, // 10 basis points
                maxAllowanceRate: 10000,
                minAllocationActivity: 3600,
                maxAllocationActivity: 604800,
                tokenAllowanceList: tokenAllowanceCapList,
                tokenAllowanceAmountList: tokenAllowanceCapAmountList
            })
        );

        dictator.setPermission(puppetLogic, puppetLogic.deposit.selector, address(puppetRouter));
        dictator.setPermission(puppetLogic, puppetLogic.withdraw.selector, address(puppetRouter));
        dictator.setPermission(puppetLogic, puppetLogic.setMatchRule.selector, address(puppetRouter));
        dictator.setPermission(puppetLogic, puppetLogic.setMatchRuleList.selector, address(puppetRouter));

        dictator.setPermission(puppetRouter, puppetRouter.setConfig.selector, Address.dao);
        puppetRouter.setConfig(PuppetRouter.Config({logic: puppetLogic}));
    }

    function deployPositionLogic() internal {
        PuppetStore puppetStore = PuppetStore(Address.PuppetStore);
        MirrorPositionStore positionStore = MirrorPositionStore(Address.MirrorPositionStore);
        ContributeStore contributeStore = ContributeStore(Address.ContributeStore);
        PositionRouter positionRouter = PositionRouter(Address.PositionRouter);

        RequestLogic requestLogic = new RequestLogic(dictator, eventEmitter, puppetStore, positionStore);
        dictator.setAccess(eventEmitter, address(requestLogic));
        dictator.setAccess(puppetStore, address(requestLogic));
        dictator.setAccess(positionStore, address(requestLogic));

        ExecutionLogic executionLogic = new ExecutionLogic(dictator, eventEmitter, puppetStore, positionStore);
        dictator.setAccess(eventEmitter, address(executionLogic));
        dictator.setAccess(positionStore, address(executionLogic));

        UnhandledCallbackLogic unhandledCallbackLogic =
            new UnhandledCallbackLogic(dictator, eventEmitter, positionStore);
        dictator.setAccess(eventEmitter, address(unhandledCallbackLogic));
        dictator.setPermission(requestLogic, requestLogic.setConfig.selector, Address.dao);

        AllocationLogic allocationLogic =
            new AllocationLogic(dictator, eventEmitter, contributeStore, puppetStore, positionStore);
        dictator.setAccess(eventEmitter, address(executionLogic));
        dictator.setAccess(contributeStore, address(executionLogic));
        dictator.setAccess(puppetStore, address(executionLogic));
        dictator.setPermission(allocationLogic, allocationLogic.setConfig.selector, Address.dao);
        allocationLogic.setConfig(
            AllocationLogic.Config({
                limitAllocationListLength: 100,
                performanceContributionRate: 0.1e30,
                traderPerformanceContributionShare: 0
            })
        );

        // config

        requestLogic.setConfig(
            RequestLogic.Config({
                gmxExchangeRouter: IGmxExchangeRouter(Address.gmxExchangeRouter),
                gmxDatastore: IGmxDatastore(Address.gmxDatastore),
                callbackHandler: Address.PositionRouter,
                gmxFundsReciever: Address.PuppetStore,
                gmxOrderVault: Address.gmxOrderVault,
                referralCode: Address.referralCode,
                callbackGasLimit: 2_000_000
            })
        );

        dictator.setPermission(positionRouter, positionRouter.setConfig.selector, Address.dao);
        positionRouter.setConfig(
            PositionRouter.Config({
                requestLogic: requestLogic,
                allocationLogic: allocationLogic,
                executionLogic: executionLogic,
                unhandledCallbackLogic: unhandledCallbackLogic
            })
        );

        // Operation

        dictator.setPermission(requestLogic, requestLogic.mirror.selector, address(positionRouter));
        dictator.setPermission(allocationLogic, allocationLogic.allocate.selector, address(positionRouter));
        dictator.setPermission(allocationLogic, allocationLogic.settle.selector, address(positionRouter));

        dictator.setPermission(positionRouter, positionRouter.afterOrderExecution.selector, Address.gmxOrderHandler);
        dictator.setPermission(positionRouter, positionRouter.afterOrderCancellation.selector, Address.gmxOrderHandler);
        dictator.setPermission(positionRouter, positionRouter.afterOrderFrozen.selector, Address.gmxOrderHandler);
        dictator.setPermission(positionRouter, positionRouter.mirror.selector, Address.dao);
        dictator.setPermission(positionRouter, positionRouter.allocate.selector, Address.dao);
        dictator.setPermission(positionRouter, positionRouter.settle.selector, Address.dao);
    }
}
