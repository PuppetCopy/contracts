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

contract DeployPositionLogic is BaseScript {
    Dictator dictator = Dictator(Address.Dictator);

    function run() public {
        vm.startBroadcast(DEPLOYER_PRIVATE_KEY);
        deployContracts();
        vm.stopBroadcast();
    }

    function deployContracts() internal {
        EventEmitter eventEmitter = EventEmitter(Address.EventEmitter);
        Router router = Router(Address.Router);
        PuppetStore puppetStore = PuppetStore(Address.PuppetStore);
        ContributeStore contributeStore = ContributeStore(Address.ContributeStore);

        MirrorPositionStore positionStore = new MirrorPositionStore(dictator, router);
        dictator.setPermission(router, router.transfer.selector, address(positionStore));
        PositionRouter positionRouter = new PositionRouter(dictator, eventEmitter, positionStore);
        dictator.setPermission(positionRouter, positionRouter.setConfig.selector, Address.dao);
        dictator.setAccess(eventEmitter, address(positionRouter));

        // MirrorPositionStore positionStore = MirrorPositionStore(Address.MirrorPositionStore);
        // PositionRouter positionRouter = PositionRouter(Address.PositionRouter);

        RequestLogic requestLogic = new RequestLogic(dictator, eventEmitter, puppetStore, positionStore);
        dictator.setPermission(requestLogic, requestLogic.setConfig.selector, Address.dao);
        dictator.setAccess(eventEmitter, address(requestLogic));
        dictator.setAccess(puppetStore, address(requestLogic));
        dictator.setAccess(positionStore, address(requestLogic));

        ExecutionLogic executionLogic = new ExecutionLogic(dictator, eventEmitter, puppetStore, positionStore);
        dictator.setAccess(eventEmitter, address(executionLogic));
        dictator.setAccess(positionStore, address(executionLogic));
        dictator.setAccess(puppetStore, address(executionLogic));

        UnhandledCallbackLogic unhandledCallbackLogic =
            new UnhandledCallbackLogic(dictator, eventEmitter, positionStore);
        dictator.setAccess(eventEmitter, address(unhandledCallbackLogic));

        AllocationLogic allocationLogic =
            new AllocationLogic(dictator, eventEmitter, contributeStore, puppetStore, positionStore);
        dictator.setPermission(allocationLogic, allocationLogic.setConfig.selector, Address.dao);
        dictator.setAccess(eventEmitter, address(allocationLogic));
        dictator.setAccess(contributeStore, address(allocationLogic));
        dictator.setAccess(puppetStore, address(allocationLogic));
        dictator.setAccess(puppetStore, address(contributeStore));

        // config
        allocationLogic.setConfig(
            AllocationLogic.Config({
                limitAllocationListLength: 100,
                performanceContributionRate: 0.1e30,
                traderPerformanceContributionShare: 0
            })
        );
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
