// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {console} from "forge-std/src/console.sol";

import {KeeperRouter} from "src/keeperRouter.sol";

import {Account as AccountContract} from "src/position/Account.sol";
import {Mirror} from "src/position/Mirror.sol";
import {Rule} from "src/position/Rule.sol";
import {Settle} from "src/position/Settle.sol";
import {IGmxExchangeRouter} from "src/position/interface/IGmxExchangeRouter.sol";
import {IGmxReadDataStore} from "src/position/interface/IGmxReadDataStore.sol";
import {AccountStore} from "src/shared/AccountStore.sol";
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

        // Deploy each contract with their permissions
        AccountStore accountStore = deployAccountStore();
        AccountContract account = deployAccount(accountStore);
        Rule ruleContract = deployRule();
        Mirror mirror = deployMirror(account);
        Settle settle = deploySettle(account);
        deployKeeperRouter(mirror, ruleContract, settle, account);

        // Set up cross-contract permissions
        setupCrossContractPermissions(mirror, ruleContract);

        // Setup upkeeping configuration
        setupUpkeepingConfig(account, settle);

        console.log("=== Position Contracts Deployment Complete ===");

        vm.stopBroadcast();
    }

    function deployAccountStore() internal returns (AccountStore) {
        console.log("\n--- Deploying AccountStore ---");

        // Deploy contract
        AccountStore accountStore = new AccountStore(dictator, tokenRouter);
        console.log("AccountStore deployed at:", address(accountStore));

        // Set up permissions
        // TokenRouter needs permission to transfer tokens for AccountStore
        dictator.setPermission(tokenRouter, tokenRouter.transfer.selector, address(accountStore));

        console.log("AccountStore permissions configured");

        return accountStore;
    }

    function deployAccount(
        AccountStore accountStore
    ) internal returns (AccountContract) {
        console.log("\n--- Deploying Account ---");

        // Deploy contract
        AccountContract account =
            new AccountContract(dictator, accountStore, AccountContract.Config({transferOutGasLimit: 200_000}));
        console.log("Account deployed at:", address(account));

        // Set up permissions
        // AccountStore access for Account
        dictator.setAccess(accountStore, address(account));

        // Initialize contract
        dictator.registerContract(account);
        console.log("Account initialized and permissions configured");

        return account;
    }

    function deploySettle(
        AccountContract account
    ) internal returns (Settle) {
        console.log("\n--- Deploying Settle ---");

        // Deploy contract
        Settle settle = new Settle(
            dictator,
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
        // AccountStore access for Settle
        dictator.setAccess(account.accountStore(), address(settle));
        // Account permissions for Settle
        dictator.setPermission(account, account.execute.selector, address(settle));
        dictator.setPermission(account, account.setBalanceList.selector, address(settle));
        dictator.setPermission(account, account.transferInAllocation.selector, address(settle));
        dictator.setPermission(account, account.transferOut.selector, address(settle));
        dictator.setPermission(account, account.getAllocationAddress.selector, address(settle));
        dictator.setPermission(account, account.transferInAllocation.selector, address(settle));
        dictator.setPermission(account, account.transferOut.selector, address(settle));
        dictator.setPermission(account, account.getAllocationAddress.selector, address(settle));

        // Initialize contract
        dictator.registerContract(settle);
        console.log("Settle initialized and permissions configured");

        return settle;
    }

    function deployRule() internal returns (Rule ruleContract) {
        console.log("\n--- Deploying Rule Contract ---");

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

        // Initialize contract
        dictator.registerContract(ruleContract);
        console.log("Rule contract initialized and permissions configured");

        return ruleContract;
    }

    function deployMirror(
        AccountContract account
    ) internal returns (Mirror) {
        console.log("\n--- Deploying Mirror ---");

        // Deploy contract
        Mirror mirror = new Mirror(
            dictator,
            Mirror.Config({
                gmxExchangeRouter: IGmxExchangeRouter(Const.gmxExchangeRouter),
                gmxDataStore: IGmxReadDataStore(Const.gmxDataStore),
                gmxOrderVault: Const.gmxOrderVault,
                referralCode: Const.referralCode,
                increaseCallbackGasLimit: 2e6,
                decreaseCallbackGasLimit: 2e6,
                fallbackRefundExecutionFeeReceiver: Const.dao,
                maxPuppetList: 50,
                maxKeeperFeeToAllocationRatio: 0.1e30,
                maxKeeperFeeToAdjustmentRatio: 0.1e30
            })
        );
        console.log("Mirror deployed at:", address(mirror));

        // Set up permissions
        // Account permissions for Mirror
        dictator.setPermission(account, account.execute.selector, address(mirror));
        dictator.setPermission(account, account.setUserBalance.selector, address(mirror));
        dictator.setPermission(account, account.setBalanceList.selector, address(mirror));
        dictator.setPermission(account, account.createAllocationAccount.selector, address(mirror));
        dictator.setPermission(account, account.getBalanceList.selector, address(mirror));
        dictator.setPermission(account, account.transferOut.selector, address(mirror));
        dictator.setPermission(account, account.getAllocationAddress.selector, address(mirror));
        dictator.setPermission(account, account.getBalanceList.selector, address(mirror));
        dictator.setPermission(account, account.transferOut.selector, address(mirror));
        dictator.setPermission(account, account.getAllocationAddress.selector, address(mirror));

        // Initialize contract
        dictator.registerContract(mirror);
        console.log("Mirror initialized and permissions configured");

        return mirror;
    }

    function deployKeeperRouter(
        Mirror mirror,
        Rule ruleContract,
        Settle settle,
        AccountContract account
    ) internal returns (KeeperRouter) {
        console.log("\n--- Deploying KeeperRouter ---");

        // Deploy contract with empirical gas configuration
        KeeperRouter keeperRouter = new KeeperRouter(
            dictator,
            account,
            ruleContract,
            mirror,
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
        dictator.setPermission(settle, settle.collectAllocationAccountDust.selector, address(keeperRouter));

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
        dictator.setPermission(keeperRouter, keeperRouter.collectAllocationAccountDust.selector, Const.keeper);

        // Initialize contract
        dictator.registerContract(keeperRouter);
        console.log("KeeperRouter initialized and permissions configured");

        return keeperRouter;
    }

    function setupCrossContractPermissions(Mirror mirror, Rule ruleContract) internal {
        console.log("\n--- Setting up cross-contract permissions ---");

        // Rule needs permission to initialize trader activity throttle via Mirror
        dictator.setPermission(mirror, mirror.initializeTraderActivityThrottle.selector, address(ruleContract));

        console.log("Cross-contract permissions configured");
    }

    function setupUpkeepingConfig(AccountContract account, Settle settle) internal {
        console.log("\n--- Setting up upkeeping configuration ---");

        // Set up DAO permissions for configuration
        dictator.setPermission(account, account.setDepositCapList.selector, Const.dao);
        dictator.setPermission(settle, settle.setTokenDustThresholdList.selector, Const.dao);

        // Configure USDC as allowed token
        IERC20[] memory allowedTokens = new IERC20[](1);
        allowedTokens[0] = IERC20(Const.usdc);
        uint[] memory depositCaps = new uint[](1);
        depositCaps[0] = 100e6; // 100 USDC cap
        account.setDepositCapList(allowedTokens, depositCaps);

        // Configure dust threshold for USDC
        uint[] memory dustTokenThresholds = new uint[](1);
        dustTokenThresholds[0] = 0.1e6; // 0.1 USDC threshold
        settle.setTokenDustThresholdList(allowedTokens, dustTokenThresholds);

        console.log("Upkeeping configuration complete");
    }
}
