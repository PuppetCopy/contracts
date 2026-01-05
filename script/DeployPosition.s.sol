// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Dictatorship} from "src/shared/Dictatorship.sol";
import {Allocate} from "src/position/Allocate.sol";
import {Match} from "src/position/Match.sol";
import {Position} from "src/position/Position.sol";
import {GmxStage} from "src/position/stage/GmxStage.sol";
import {MasterHook} from "src/account/MasterHook.sol";
import {UserRouter} from "src/UserRouter.sol";
import {ProxyUserRouter} from "src/utils/ProxyUserRouter.sol";
import {IUserRouter} from "src/utils/interfaces/IUserRouter.sol";
import {IStage} from "src/position/interface/IStage.sol";
import {CoreContract} from "src/utils/CoreContract.sol";

import {BaseScript} from "./BaseScript.s.sol";
import {Const} from "./Const.sol";

contract DeployPosition is BaseScript {
    function run() public {
        vm.startBroadcast(DEPLOYER_PRIVATE_KEY);

        Dictatorship dictatorship = new Dictatorship(DEPLOYER_ADDRESS);
        ProxyUserRouter proxyUserRouter = new ProxyUserRouter(dictatorship);
        MasterHook masterHook = new MasterHook(IUserRouter(address(proxyUserRouter)));
        Position position = new Position(dictatorship);
        Match matcher = new Match(dictatorship);
        Allocate allocation = new Allocate(
            dictatorship,
            Allocate.Config({masterHook: address(masterHook), maxPuppetList: 100, withdrawGasLimit: 200_000})
        );
        UserRouter userRouterImpl = new UserRouter(
            dictatorship, UserRouter.Config({allocation: allocation, matcher: matcher, position: position})
        );
        GmxStage gmxStage = new GmxStage(Const.gmxDataStore, Const.gmxExchangeRouter, Const.gmxOrderVault, Const.wnt);

        dictatorship.registerContract(address(proxyUserRouter));
        dictatorship.registerContract(address(position));
        dictatorship.registerContract(address(matcher));
        dictatorship.registerContract(address(allocation));

        dictatorship.setPermission(position, position.processPostCall.selector, address(proxyUserRouter));

        dictatorship.setPermission(matcher, matcher.recordThrottle.selector, address(allocation));
        dictatorship.setPermission(matcher, matcher.setFilter.selector, address(proxyUserRouter));
        dictatorship.setPermission(matcher, matcher.setPolicy.selector, address(proxyUserRouter));

        dictatorship.setPermission(allocation, allocation.registerMasterSubaccount.selector, address(proxyUserRouter));
        dictatorship.setPermission(allocation, allocation.disposeSubaccount.selector, address(proxyUserRouter));

        dictatorship.setPermission(position, position.settleOrders.selector, DEPLOYER_ADDRESS);
        dictatorship.setPermission(allocation, allocation.executeAllocate.selector, DEPLOYER_ADDRESS);
        dictatorship.setPermission(allocation, allocation.executeWithdraw.selector, DEPLOYER_ADDRESS);

        dictatorship.setPermission(position, position.setHandler.selector, DEPLOYER_ADDRESS);
        position.setHandler(Const.gmxExchangeRouter, IStage(address(gmxStage)));
        dictatorship.setPermission(allocation, allocation.setCodeHash.selector, DEPLOYER_ADDRESS);
        allocation.setCodeHash(Const.account7579CodeHash, true);
        dictatorship.setPermission(allocation, allocation.setTokenCap.selector, DEPLOYER_ADDRESS);
        allocation.setTokenCap(IERC20(Const.usdc), 100e6);

        dictatorship.setAccess(proxyUserRouter, DEPLOYER_ADDRESS);
        proxyUserRouter.update(address(userRouterImpl));

        vm.stopBroadcast();
    }
}
