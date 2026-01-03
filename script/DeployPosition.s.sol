// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Dictatorship} from "src/shared/Dictatorship.sol";
import {Allocation} from "src/position/Allocation.sol";
import {Position} from "src/position/Position.sol";
import {SubscriptionPolicy} from "src/position/policies/SubscriptionPolicy.sol";
import {GmxStage} from "src/position/stage/GmxStage.sol";
import {MasterHook} from "src/account/MasterHook.sol";
import {UserRouter} from "src/UserRouter.sol";
import {IUserRouter} from "src/utils/interfaces/IUserRouter.sol";
import {IStage} from "src/position/interface/IStage.sol";
import {IAuthority} from "src/utils/interfaces/IAuthority.sol";
import {Permission} from "src/utils/auth/Permission.sol";

import {BaseScript} from "./BaseScript.s.sol";
import {Const} from "./Const.sol";

contract DeployPosition is BaseScript {

    function run() public {
        vm.startBroadcast(DEPLOYER_PRIVATE_KEY);

        Dictatorship dictatorship = new Dictatorship(DEPLOYER_ADDRESS);
        Position position = new Position(dictatorship);

        // Deploy Allocation with placeholder masterHook (will update after MasterHook deployment)
        Allocation allocation = new Allocation(
            dictatorship,
            Allocation.Config({
                position: position, masterHook: address(1), maxPuppetList: 100, transferGasLimit: 200_000
            })
        );

        // Deploy UserRouter and MasterHook
        UserRouter userRouter =
            new UserRouter(dictatorship, UserRouter.Config({allocation: allocation, position: position}));
        MasterHook masterHook = new MasterHook(IUserRouter(address(userRouter)));

        // Update Allocation config with actual MasterHook address
        dictatorship.setPermission(Permission(address(allocation)), allocation.setConfig.selector, DEPLOYER_ADDRESS);
        allocation.setConfig(
            abi.encode(
                Allocation.Config({
                    position: position,
                    masterHook: address(masterHook),
                    maxPuppetList: 100,
                    transferGasLimit: 200_000
                })
            )
        );

        // Set allowed account code hash (Kernel v3.3 proxy bytecode hash)
        dictatorship.setPermission(Permission(address(allocation)), allocation.setCodeHash.selector, DEPLOYER_ADDRESS);
        allocation.setCodeHash(Const.account7579CodeHash, true);

        SubscriptionPolicy subscriptionPolicy = new SubscriptionPolicy(
            IAuthority(address(dictatorship)), abi.encode(SubscriptionPolicy.Config({version: 1}))
        );

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
        dictatorship.setPermission(Permission(address(allocation)), Allocation.setTokenCap.selector, DEPLOYER_ADDRESS);
        allocation.setTokenCap(IERC20(Const.usdc), 100e6);

        dictatorship.setPermission(
            Permission(address(allocation)), Allocation.executeAllocate.selector, DEPLOYER_ADDRESS
        );
        dictatorship.setPermission(
            Permission(address(allocation)), Allocation.executeWithdraw.selector, DEPLOYER_ADDRESS
        );

        vm.stopBroadcast();
    }
}
