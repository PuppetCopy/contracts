// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import {IGasFeeCallbackReceiver} from "@gmx/contracts/callback/IGasFeeCallbackReceiver.sol";
import {IOrderCallbackReceiver} from "@gmx/contracts/callback/IOrderCallbackReceiver.sol";
import {console} from "forge-std/src/console.sol";

import {KeeperRouter} from "src/keeperRouter.sol";
import {Allocate} from "src/position/Allocate.sol";
import {MatchingRule} from "src/position/MatchingRule.sol";
import {MirrorPosition} from "src/position/MirrorPosition.sol";
import {Settle} from "src/position/Settle.sol";
import {IGmxExchangeRouter} from "src/position/interface/IGmxExchangeRouter.sol";
import {AllocationStore} from "src/shared/AllocationStore.sol";
import {Dictatorship} from "src/shared/Dictatorship.sol";
import {TokenRouter} from "src/shared/TokenRouter.sol";

import {BaseScript} from "./BaseScript.s.sol";
import {Const} from "./Const.sol";

/**
 * @title DeployPosition
 * @notice Deployment script for the Mirror Position trading system
 * @dev Each contract can be deployed independently with its own permissions
 */
contract DeployPosition is BaseScript {
    // State variables to hold deployed contracts
    Dictatorship dictator;
    TokenRouter tokenRouter;

    function run() public {
        vm.startBroadcast(DEPLOYER_PRIVATE_KEY);

        verifySelectorsMatch();

        // Get base infrastructure
        // dictator = Dictatorship(getDeployedAddress("Dictatorship"));
        // tokenRouter = TokenRouter(getDeployedAddress("TokenRouter"));

        // console.log("=== Deploying Position Contracts ===");

        // // Deploy each contract with its permissions
        // AllocationStore allocationStore = deployAllocationStore();
        // MatchingRule matchingRule = deployMatchingRule(allocationStore);

        // Allocate allocate = deployAllocate(allocationStore, matchingRule);
        // Settle settle = deploySettle(allocationStore);
        // MirrorPosition mirrorPosition = deployMirrorPosition();
        // KeeperRouter keeperRouter = deployKeeperRouter(mirrorPosition, matchingRule, allocate, settle);

        // console.log("=== Position Contracts Deployment Complete ===");

        vm.stopBroadcast();
    }

    /**
     * @notice Deploys AllocationStore and sets up its permissions
     * @return allocationStore The deployed AllocationStore contract
     */
    function deployAllocationStore() internal returns (AllocationStore) {
        console.log("\n--- Deploying AllocationStore ---");

        // Deploy contract
        AllocationStore allocationStore = new AllocationStore(dictator, tokenRouter);
        console.log("AllocationStore deployed at:", address(allocationStore));

        // Set up permissions
        // TokenRouter needs permission to transfer tokens for AllocationStore
        dictator.setPermission(tokenRouter, tokenRouter.transfer.selector, address(allocationStore));

        // No initialization needed for AllocationStore
        console.log("AllocationStore permissions configured");

        return allocationStore;
    }

    /**
     * @notice Deploys Allocate contract and sets up its permissions
     * @param allocationStore The AllocationStore contract to use
     * @return allocate The deployed Allocate contract
     */
    function deployAllocate(AllocationStore allocationStore, MatchingRule matchingRule) internal returns (Allocate) {
        console.log("\n--- Deploying Allocate ---");

        // Deploy contract
        Allocate allocate = new Allocate(
            dictator,
            allocationStore,
            Allocate.Config({
                transferOutGasLimit: 200_000,
                maxPuppetList: 50,
                maxKeeperFeeToAllocationRatio: 0.1e30, // 10%
                maxKeeperFeeToAdjustmentRatio: 0.1e30, // 10%
                gmxOrderVault: Const.gmxOrderVault
            })
        );
        console.log("Allocate deployed at:", address(allocate));

        // Set up permissions
        // AllocationStore access for Allocate
        dictator.setAccess(allocationStore, address(allocate));

        // MatchingRule needs to initialize trader activity throttle
        dictator.setPermission(allocate, allocate.initializeTraderActivityThrottle.selector, address(matchingRule));

        // Initialize contract
        dictator.registerContract(allocate);
        console.log("Allocate initialized and permissions configured");

        return allocate;
    }

    /**
     * @notice Deploys Settle contract and sets up its permissions
     * @param allocationStore The AllocationStore contract to use
     * @return settle The deployed Settle contract
     */
    function deploySettle(
        AllocationStore allocationStore
    ) internal returns (Settle) {
        console.log("\n--- Deploying Settle ---");

        // Deploy contract
        Settle settle = new Settle(
            dictator,
            allocationStore,
            Settle.Config({
                transferOutGasLimit: 200_000,
                platformSettleFeeFactor: 0.01e30, // 1%
                maxKeeperFeeToSettleRatio: 0.1e30, // 10%
                maxPuppetList: 50,
                allocationAccountTransferGasLimit: 100_000
            })
        );
        console.log("Settle deployed at:", address(settle));

        // Set up permissions
        // AllocationStore access for Settle
        dictator.setAccess(allocationStore, address(settle));

        // Initialize contract
        dictator.registerContract(settle);
        console.log("Settle initialized and permissions configured");

        return settle;
    }

    /**
     * @notice Deploys MatchingRule contract and sets up its permissions
     * @param allocationStore The AllocationStore contract to use
     * @return matchingRule The deployed MatchingRule contract
     */
    function deployMatchingRule(
        AllocationStore allocationStore
    ) internal returns (MatchingRule) {
        console.log("\n--- Deploying MatchingRule ---");

        // Deploy contract
        MatchingRule matchingRule = new MatchingRule(
            dictator,
            allocationStore,
            MatchingRule.Config({
                transferOutGasLimit: 200_000,
                minExpiryDuration: 1 hours,
                minAllowanceRate: 100, // 1%
                maxAllowanceRate: 10000, // 100%
                minActivityThrottle: 1 hours,
                maxActivityThrottle: 30 days
            })
        );
        console.log("MatchingRule deployed at:", address(matchingRule));

        // Set up permissions
        // AllocationStore access for MatchingRule
        dictator.setAccess(allocationStore, address(matchingRule));

        // Initialize contract
        dictator.registerContract(matchingRule);
        console.log("MatchingRule initialized and permissions configured");

        return matchingRule;
    }

    /**
     * @notice Deploys MirrorPosition contract and sets up its permissions
     * @return mirrorPosition The deployed MirrorPosition contract
     */
    function deployMirrorPosition() internal returns (MirrorPosition) {
        console.log("\n--- Deploying MirrorPosition ---");

        // Deploy contract
        MirrorPosition mirrorPosition = new MirrorPosition(
            dictator,
            MirrorPosition.Config({
                gmxExchangeRouter: IGmxExchangeRouter(Const.gmxExchangeRouter),
                gmxOrderVault: Const.gmxOrderVault,
                referralCode: Const.referralCode,
                increaseCallbackGasLimit: 2e6,
                decreaseCallbackGasLimit: 2e6,
                fallbackRefundExecutionFeeReceiver: Const.dao
            })
        );
        console.log("MirrorPosition deployed at:", address(mirrorPosition));

        // MirrorPosition has no standalone permissions, they're set up via KeeperRouter

        // Initialize contract
        dictator.registerContract(mirrorPosition);
        console.log("MirrorPosition initialized");

        return mirrorPosition;
    }

    /**
     * @notice Deploys KeeperRouter and sets up permissions for all contracts
     * @dev KeeperRouter is the composition layer that brings all contracts together
     * @param mirrorPosition The MirrorPosition contract
     * @param matchingRule The MatchingRule contract
     * @param allocate The Allocate contract
     * @param settle The Settle contract
     * @return keeperRouter The deployed KeeperRouter contract
     */
    function deployKeeperRouter(
        MirrorPosition mirrorPosition,
        MatchingRule matchingRule,
        Allocate allocate,
        Settle settle
    ) internal returns (KeeperRouter) {
        console.log("\n--- Deploying KeeperRouter ---");

        // Deploy contract with empirical gas configuration
        KeeperRouter keeperRouter = new KeeperRouter(
            dictator,
            mirrorPosition,
            matchingRule,
            allocate,
            settle,
            KeeperRouter.Config({
                mirrorBaseGasLimit: 1_300_853, // Based on empirical single-puppet test
                mirrorPerPuppetGasLimit: 30_000, // Conservative estimate for additional puppets
                adjustBaseGasLimit: 910_663, // Keep existing (need adjust operation analysis)
                adjustPerPuppetGasLimit: 3_412, // Keep existing (need adjust operation analysis)
                fallbackRefundExecutionFeeReceiver: Const.dao // Fallback receiver for execution fee refunds
            })
        );
        console.log("KeeperRouter deployed at:", address(keeperRouter));

        // Set up permissions for KeeperRouter to call other contracts
        console.log("Setting up KeeperRouter permissions...");

        // Allocate permissions
        dictator.setPermission(allocate, allocate.createAllocation.selector, address(keeperRouter));
        dictator.setPermission(allocate, allocate.collectKeeperFee.selector, address(keeperRouter));

        // Settle permissions
        dictator.setPermission(settle, settle.settle.selector, address(keeperRouter));
        dictator.setPermission(settle, settle.collectDust.selector, address(keeperRouter));
        dictator.setPermission(settle, settle.setTokenDustThresholdList.selector, Const.dao);

        // MirrorPosition permissions
        dictator.setPermission(mirrorPosition, mirrorPosition.requestMirror.selector, address(keeperRouter));
        dictator.setPermission(mirrorPosition, mirrorPosition.requestAdjust.selector, address(keeperRouter));
        dictator.setPermission(mirrorPosition, mirrorPosition.execute.selector, address(keeperRouter));
        dictator.setPermission(mirrorPosition, mirrorPosition.liquidate.selector, address(keeperRouter));

        // GMX callback permissions for KeeperRouter
        console.log("Setting up GMX callback permissions...");
        dictator.setPermission(keeperRouter, keeperRouter.afterOrderExecution.selector, Const.gmxOrderHandler);
        dictator.setPermission(keeperRouter, keeperRouter.afterOrderCancellation.selector, Const.gmxOrderHandler);
        dictator.setPermission(keeperRouter, keeperRouter.afterOrderFrozen.selector, Const.gmxOrderHandler);
        dictator.setPermission(keeperRouter, keeperRouter.refundExecutionFee.selector, Const.gmxOrderHandler);

        // Additional GMX handler permissions
        dictator.setPermission(keeperRouter, keeperRouter.afterOrderExecution.selector, Const.gmxLiquidationHandler);
        dictator.setPermission(keeperRouter, keeperRouter.afterOrderExecution.selector, Const.gmxAdlHandler);

        dictator.setPermission(keeperRouter, keeperRouter.refundExecutionFee.selector, address(keeperRouter));

        // External keeper permissions
        console.log("Setting up external keeper permissions...");
        dictator.setPermission(keeperRouter, keeperRouter.requestMirror.selector, Const.keeper);
        dictator.setPermission(keeperRouter, keeperRouter.requestAdjust.selector, Const.keeper);
        dictator.setPermission(keeperRouter, keeperRouter.settleAllocation.selector, Const.keeper);
        dictator.setPermission(keeperRouter, keeperRouter.collectDust.selector, Const.keeper);

        // Initialize contract
        dictator.registerContract(keeperRouter);
        console.log("KeeperRouter initialized and permissions configured");

        return keeperRouter;
    }

    /**
     * @notice Upgrade a specific contract while maintaining permissions
     * @dev Can be called to upgrade individual contracts
     */
    function upgradeAllocate(
        AllocationStore allocationStore,
        MatchingRule matchingRule,
        KeeperRouter keeperRouter
    ) public returns (Allocate) {
        console.log("\n--- Upgrading Allocate ---");
        Allocate newAllocate = deployAllocate(allocationStore, matchingRule);

        // Grant KeeperRouter permissions to new Allocate contract
        dictator.setPermission(newAllocate, newAllocate.createAllocation.selector, address(keeperRouter));
        dictator.setPermission(newAllocate, newAllocate.collectKeeperFee.selector, address(keeperRouter));

        console.log("Allocate upgrade complete with KeeperRouter permissions");
        return newAllocate;
    }

    function upgradeSettle(AllocationStore allocationStore, KeeperRouter keeperRouter) public returns (Settle) {
        console.log("\n--- Upgrading Settle ---");
        Settle newSettle = deploySettle(allocationStore);

        // Grant KeeperRouter permissions to new Settle contract
        dictator.setPermission(newSettle, newSettle.settle.selector, address(keeperRouter));
        dictator.setPermission(newSettle, newSettle.collectDust.selector, address(keeperRouter));

        console.log("Settle upgrade complete with KeeperRouter permissions");
        return newSettle;
    }

    function upgradeMatchingRule(
        AllocationStore allocationStore
    ) public returns (MatchingRule) {
        console.log("\n--- Upgrading MatchingRule ---");
        MatchingRule newMatchingRule = deployMatchingRule(allocationStore);
        // MatchingRule doesn't need KeeperRouter permissions directly
        console.log("MatchingRule upgrade complete");
        return newMatchingRule;
    }

    function upgradeMirrorPosition(
        KeeperRouter keeperRouter
    ) public returns (MirrorPosition) {
        console.log("\n--- Upgrading MirrorPosition ---");
        MirrorPosition newMirrorPosition = deployMirrorPosition();

        // Grant KeeperRouter permissions to new MirrorPosition contract
        dictator.setPermission(newMirrorPosition, newMirrorPosition.requestMirror.selector, address(keeperRouter));
        dictator.setPermission(newMirrorPosition, newMirrorPosition.requestAdjust.selector, address(keeperRouter));
        dictator.setPermission(newMirrorPosition, newMirrorPosition.execute.selector, address(keeperRouter));
        dictator.setPermission(newMirrorPosition, newMirrorPosition.liquidate.selector, address(keeperRouter));

        console.log("MirrorPosition upgrade complete with KeeperRouter permissions");
        return newMirrorPosition;
    }

    function verifySelectorsMatch() public pure {
        console.log("\n=== Verifying Selector Compatibility ===");

        KeeperRouter tempCallback = KeeperRouter(address(0)); // Use a zero address for selector matching

        console.log(
            "Matching afterOrderExecution? ",
            IOrderCallbackReceiver.afterOrderExecution.selector == tempCallback.afterOrderExecution.selector
                ? "YES"
                : "NO"
        );
        console.log(
            "Matching afterOrderCancellation? ",
            IOrderCallbackReceiver.afterOrderCancellation.selector == tempCallback.afterOrderCancellation.selector
                ? "YES"
                : "NO"
        );
        console.log(
            "Matching afterOrderFrozen? ",
            IOrderCallbackReceiver.afterOrderFrozen.selector == tempCallback.afterOrderFrozen.selector ? "YES" : "NO"
        );
        console.log(
            "Matching refundExecutionFee? ",
            IGasFeeCallbackReceiver.refundExecutionFee.selector == tempCallback.refundExecutionFee.selector
                ? "YES"
                : "NO"
        );
    }
}
