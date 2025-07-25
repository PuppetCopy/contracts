// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {console} from "forge-std/src/console.sol";

import {KeeperRouter} from "src/keeperRouter.sol";

import {Deposit} from "src/position/Deposit.sol";
import {Mirror} from "src/position/Mirror.sol";
import {Rule} from "src/position/Rule.sol";
import {Settle} from "src/position/Settle.sol";
import {IGmxExchangeRouter} from "src/position/interface/IGmxExchangeRouter.sol";
import {IGmxReadDataStore} from "src/position/interface/IGmxReadDataStore.sol";
import {AllocationStore} from "src/shared/AllocationStore.sol";
import {Dictatorship} from "src/shared/Dictatorship.sol";
import {TokenRouter} from "src/shared/TokenRouter.sol";

import {BaseScript} from "./BaseScript.s.sol";
import {Const} from "./Const.sol";

/**
 * @title DeployPosition
 * @notice Deployment script for the core position trading system
 * @dev Deploys all core position contracts with proper permissions
 */
contract DeployPosition is BaseScript {
    // State variables to hold deployed contracts
    Dictatorship dictator = Dictatorship(getDeployedAddress("Dictatorship"));
    TokenRouter tokenRouter = TokenRouter(getDeployedAddress("TokenRouter"));

    function run() public {
        vm.startBroadcast(DEPLOYER_PRIVATE_KEY);

        console.log("=== Deploying Position Contracts ===");

        // Deploy each contract with its permissions
        AllocationStore allocationStore = deployAllocationStore();
        (Rule ruleContract, Deposit depositContract) = deployRuleAndDeposit(allocationStore);
        Settle settle = deploySettle(allocationStore);
        Mirror mirror = deployMirror(allocationStore);
        deployKeeperRouter(mirror, ruleContract, settle);

        // Set up cross-contract permissions
        setupCrossContractPermissions(mirror, ruleContract);

        // Setup upkeeping configuration
        setupUpkeepingConfig(depositContract, settle);

        console.log("=== Position Contracts Deployment Complete ===");

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

        console.log("AllocationStore permissions configured");

        return allocationStore;
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
     * @notice Deploys Rule and Deposit contracts and sets up their permissions
     * @param allocationStore The AllocationStore contract to use
     * @return ruleContract The deployed Rule contract
     * @return depositContract The deployed Deposit contract
     */
    function deployRuleAndDeposit(
        AllocationStore allocationStore
    ) internal returns (Rule ruleContract, Deposit depositContract) {
        console.log("\n--- Deploying Rule and Deposit Contracts ---");

        // Deploy Rule contract
        ruleContract = new Rule(
            dictator,
            Rule.Config({
                minExpiryDuration: 1 hours,
                minAllowanceRate: 100, // 1%
                maxAllowanceRate: 10000, // 100%
                minActivityThrottle: 1 hours,
                maxActivityThrottle: 30 days
            })
        );
        console.log("Rule deployed at:", address(ruleContract));

        // Deploy Deposit contract
        depositContract = new Deposit(dictator, allocationStore, Deposit.Config({transferOutGasLimit: 200_000}));
        console.log("Deposit deployed at:", address(depositContract));

        // Set up permissions
        // AllocationStore access for Deposit contract
        dictator.setAccess(allocationStore, address(depositContract));

        // Initialize contracts
        dictator.registerContract(ruleContract);
        dictator.registerContract(depositContract);
        console.log("Rule and Deposit contracts initialized and permissions configured");

        return (ruleContract, depositContract);
    }

    /**
     * @notice Deploys Mirror contract and sets up its permissions
     * @return mirror The deployed Mirror contract
     */
    function deployMirror(
        AllocationStore allocationStore
    ) internal returns (Mirror) {
        console.log("\n--- Deploying Mirror ---");

        // Deploy contract
        Mirror mirror = new Mirror(
            dictator,
            allocationStore,
            Mirror.Config({
                gmxExchangeRouter: IGmxExchangeRouter(Const.gmxExchangeRouter),
                gmxDataStore: IGmxReadDataStore(Const.gmxDataStore),
                gmxOrderVault: Const.gmxOrderVault,
                referralCode: Const.referralCode,
                increaseCallbackGasLimit: 2e6,
                decreaseCallbackGasLimit: 2e6,
                fallbackRefundExecutionFeeReceiver: Const.dao,
                transferOutGasLimit: 200_000,
                maxPuppetList: 50,
                maxKeeperFeeToAllocationRatio: 0.1e30,
                maxKeeperFeeToAdjustmentRatio: 0.1e30
            })
        );
        console.log("Mirror deployed at:", address(mirror));

        // Set up permissions
        dictator.setAccess(allocationStore, address(mirror));

        // Initialize contract
        dictator.registerContract(mirror);
        console.log("Mirror initialized and permissions configured");

        return mirror;
    }

    /**
     * @notice Deploys KeeperRouter and sets up permissions for all contracts
     * @dev KeeperRouter is the composition layer that brings all contracts together
     * @param mirror The Mirror contract
     * @param ruleContract The Rule contract
     * @param settle The Settle contract
     * @return keeperRouter The deployed KeeperRouter contract
     */
    function deployKeeperRouter(Mirror mirror, Rule ruleContract, Settle settle) internal returns (KeeperRouter) {
        console.log("\n--- Deploying KeeperRouter ---");

        // Deploy contract with empirical gas configuration
        KeeperRouter keeperRouter = new KeeperRouter(
            dictator,
            mirror,
            ruleContract,
            settle,
            KeeperRouter.Config({
                mirrorBaseGasLimit: 1_283_731,
                mirrorPerPuppetGasLimit: 30_000,
                adjustBaseGasLimit: 910_663,
                adjustPerPuppetGasLimit: 3_412,
                settleBaseGasLimit: 90_847,
                settlePerPuppetGasLimit: 15_000,
                fallbackRefundExecutionFeeReceiver: Const.dao
            })
        );
        console.log("KeeperRouter deployed at:", address(keeperRouter));

        // Set up permissions for KeeperRouter to call other contracts
        console.log("Setting up KeeperRouter permissions...");

        // Settle permissions
        dictator.setPermission(settle, settle.settle.selector, address(keeperRouter));
        dictator.setPermission(settle, settle.collectDust.selector, address(keeperRouter));

        // Mirror permissions
        dictator.setPermission(mirror, mirror.requestOpen.selector, address(keeperRouter));
        dictator.setPermission(mirror, mirror.requestAdjust.selector, address(keeperRouter));
        dictator.setPermission(mirror, mirror.requestCloseStalledPosition.selector, address(keeperRouter));
        dictator.setPermission(mirror, mirror.execute.selector, address(keeperRouter));
        dictator.setPermission(mirror, mirror.liquidate.selector, address(keeperRouter));

        // GMX callback permissions for KeeperRouter
        console.log("Setting up GMX callback permissions...");
        dictator.setPermission(keeperRouter, keeperRouter.afterOrderExecution.selector, Const.gmxOrderHandler);
        dictator.setPermission(keeperRouter, keeperRouter.afterOrderCancellation.selector, Const.gmxOrderHandler);
        dictator.setPermission(keeperRouter, keeperRouter.afterOrderFrozen.selector, Const.gmxOrderHandler);
        dictator.setPermission(keeperRouter, keeperRouter.refundExecutionFee.selector, Const.gmxOrderHandler);

        // Additional GMX handler permissions
        dictator.setPermission(keeperRouter, keeperRouter.afterOrderExecution.selector, Const.gmxLiquidationHandler);
        dictator.setPermission(keeperRouter, keeperRouter.afterOrderExecution.selector, Const.gmxAdlHandler);

        // Self-permission for refund
        dictator.setPermission(keeperRouter, keeperRouter.refundExecutionFee.selector, address(keeperRouter));

        // External keeper permissions
        console.log("Setting up external keeper permissions...");
        dictator.setPermission(keeperRouter, keeperRouter.requestOpen.selector, Const.keeper);
        dictator.setPermission(keeperRouter, keeperRouter.requestAdjust.selector, Const.keeper);
        dictator.setPermission(keeperRouter, keeperRouter.settleAllocation.selector, Const.keeper);
        dictator.setPermission(keeperRouter, keeperRouter.collectDust.selector, Const.keeper);

        // Initialize contract
        dictator.registerContract(keeperRouter);
        console.log("KeeperRouter initialized and permissions configured");

        return keeperRouter;
    }

    /**
     * @notice Sets up cross-contract permissions between Mirror and Rule
     * @dev Mirror needs to call Rule for activity throttle initialization
     */
    function setupCrossContractPermissions(Mirror mirror, Rule ruleContract) internal {
        console.log("\n--- Setting up cross-contract permissions ---");

        // Mirror needs permission to initialize trader activity throttle via Rule
        dictator.setPermission(mirror, mirror.initializeTraderActivityThrottle.selector, address(ruleContract));

        console.log("Cross-contract permissions configured");
    }

    /**
     * @notice Sets up upkeeping configuration for token allowances and dust thresholds
     * @param depositContract The Deposit contract
     * @param settle The Settle contract
     */
    function setupUpkeepingConfig(Deposit depositContract, Settle settle) internal {
        console.log("\n--- Setting up upkeeping configuration ---");

        // Set up DAO permissions for configuration
        dictator.setPermission(depositContract, depositContract.setTokenAllowanceList.selector, Const.dao);
        dictator.setPermission(settle, settle.setTokenDustThresholdList.selector, Const.dao);

        // Configure USDC as allowed token
        IERC20[] memory allowedTokens = new IERC20[](1);
        allowedTokens[0] = IERC20(Const.usdc);
        uint[] memory allowanceCaps = new uint[](1);
        allowanceCaps[0] = 100e6; // 100 USDC cap
        depositContract.setTokenAllowanceList(allowedTokens, allowanceCaps);

        // Configure dust threshold for USDC
        uint[] memory dustTokenThresholds = new uint[](1);
        dustTokenThresholds[0] = 0.1e6; // 0.1 USDC threshold
        settle.setTokenDustThresholdList(allowedTokens, dustTokenThresholds);

        console.log("Upkeeping configuration complete");
    }
}
