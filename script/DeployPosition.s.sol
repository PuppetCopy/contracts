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
import {IUserRouter} from "src/utils/interfaces/IUserRouter.sol";
import {IStage} from "src/position/interface/IStage.sol";
import {Permission} from "src/utils/auth/Permission.sol";
import {CoreContract} from "src/utils/CoreContract.sol";

import {BaseScript} from "./BaseScript.s.sol";
import {Const} from "./Const.sol";

contract DeployPosition is BaseScript {

    function run() public {
        vm.startBroadcast(DEPLOYER_PRIVATE_KEY);

        Dictatorship dictatorship = new Dictatorship(DEPLOYER_ADDRESS);
        Position position = new Position(dictatorship);

        // Deploy Match
        Match matcher = new Match(dictatorship, abi.encode(Match.Config({gasLimit: 200_000})));
        dictatorship.registerContract(address(matcher));

        // Deploy Allocate with placeholder masterHook (will update after MasterHook deployment)
        Allocate allocation = new Allocate(
            dictatorship,
            Allocate.Config({
                masterHook: address(1),
                maxPuppetList: 100,
                withdrawGasLimit: 200_000
            })
        );

        // Deploy UserRouter and MasterHook
        UserRouter userRouter =
            new UserRouter(dictatorship, UserRouter.Config({allocation: allocation, matcher: matcher, position: position}));
        MasterHook masterHook = new MasterHook(IUserRouter(address(userRouter)));

        // Register Allocate and update config with actual MasterHook address
        dictatorship.registerContract(address(allocation));
        dictatorship.setConfig(
            CoreContract(address(allocation)),
            abi.encode(
                Allocate.Config({
                    masterHook: address(masterHook),
                    maxPuppetList: 100,
                    withdrawGasLimit: 200_000
                })
            )
        );

        // Permission for Allocate to call Match.executeMatch
        dictatorship.setPermission(
            Permission(address(matcher)), matcher.executeMatch.selector, address(allocation)
        );

        // Permission for UserRouter to call Match puppet functions
        dictatorship.setPermission(Permission(address(matcher)), matcher.setFilter.selector, address(userRouter));
        dictatorship.setPermission(Permission(address(matcher)), matcher.setPolicy.selector, address(userRouter));

        // Set allowed account code hash (Kernel v3.3 proxy bytecode hash)
        dictatorship.setPermission(Permission(address(allocation)), allocation.setCodeHash.selector, DEPLOYER_ADDRESS);
        allocation.setCodeHash(Const.account7579CodeHash, true);

        // Deploy GmxStage handler
        GmxStage gmxStage = new GmxStage(
            Const.gmxDataStore,
            Const.gmxExchangeRouter,
            Const.gmxOrderVault,
            Const.wnt
        );

        // Register GmxStage as handler for GMX ExchangeRouter
        dictatorship.setPermission(
            Permission(address(position)), position.setHandler.selector, DEPLOYER_ADDRESS
        );
        position.setHandler(Const.gmxExchangeRouter, IStage(address(gmxStage)));

        // Permission for UserRouter to call Position.processPostCall (via MasterHook.postCheck)
        dictatorship.setPermission(
            Permission(address(position)), position.processPostCall.selector, address(userRouter)
        );

        // Permission to settle orders after they complete
        dictatorship.setPermission(
            Permission(address(position)), position.settleOrders.selector, DEPLOYER_ADDRESS
        );
        dictatorship.setPermission(Permission(address(allocation)), Allocate.setTokenCap.selector, DEPLOYER_ADDRESS);
        allocation.setTokenCap(IERC20(Const.usdc), 100e6);

        dictatorship.setPermission(
            Permission(address(allocation)), Allocate.executeAllocate.selector, DEPLOYER_ADDRESS
        );
        dictatorship.setPermission(
            Permission(address(allocation)), Allocate.executeWithdraw.selector, DEPLOYER_ADDRESS
        );

        vm.stopBroadcast();
    }
}
