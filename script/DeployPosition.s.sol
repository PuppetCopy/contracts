// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {console} from "forge-std/src/console.sol";

import {SequencerRouter} from "src/SequencerRouter.sol";

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

        // Deploy each contract with their permissions
        AccountStore accountStore = deployAccountStore();
        AccountContract account = deployAccount(accountStore);
        Rule ruleContract = deployRule();
        Mirror mirror = deployMirror(account);
        Settle settle = deploySettle(account);
        SequencerRouter sequencerRouter = deploySequencerRouter(mirror, ruleContract, settle, account);

        // Set up cross-contract permissions
        setupCrossContractPermissions(mirror, ruleContract);

        // Setup upkeeping configuration
        setupUpkeepingConfig(account, settle, sequencerRouter);

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
                maxSequencerFeeToSettleRatio: 0.1e30, // 10%
                maxPuppetList: 50,
                allocationAccountTransferGasLimit: 100_000
            })
        );
        console.log("Settle deployed at:", address(settle));

        // Set up permissions
        // Account permissions for Settle
        dictator.setPermission(account, account.setBalanceList.selector, address(settle));
        dictator.setPermission(account, account.transferInAllocation.selector, address(settle));
        dictator.setPermission(account, account.transferOut.selector, address(settle));

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
                maxPuppetList: 50,
                maxSequencerFeeToAllocationRatio: 0.1e30,
                maxSequencerFeeToAdjustmentRatio: 0.1e30
            })
        );
        console.log("Mirror deployed at:", address(mirror));

        // Account permissions for Mirror
        dictator.setPermission(account, account.execute.selector, address(mirror));
        dictator.setPermission(account, account.setBalanceList.selector, address(mirror));
        dictator.setPermission(account, account.createAllocationAccount.selector, address(mirror));
        dictator.setPermission(account, account.transferOut.selector, address(mirror));

        // Initialize contract
        dictator.registerContract(mirror);
        console.log("Mirror initialized and permissions configured");

        return mirror;
    }

    function deploySequencerRouter(
        Mirror mirror,
        Rule ruleContract,
        Settle settle,
        AccountContract account
    ) internal returns (SequencerRouter) {
        console.log("\n--- Deploying SequencerRouter ---");

        // Deploy contract with empirical gas configuration
        SequencerRouter sequencerRouter = new SequencerRouter(
            dictator,
            account,
            ruleContract,
            mirror,
            settle,
            SequencerRouter.Config({
                openBaseGasLimit: 1_283_731,
                openPerPuppetGasLimit: 30_000,
                adjustBaseGasLimit: 910_663,
                adjustPerPuppetGasLimit: 3_412,
                settleBaseGasLimit: 90_847,
                settlePerPuppetGasLimit: 15_000,
                fallbackRefundExecutionFeeReceiver: Const.dao
            })
        );
        console.log("SequencerRouter deployed at:", address(sequencerRouter));

        // Set up permissions for SequencerRouter to call other contracts
        console.log("Setting up SequencerRouter permissions...");

        // Settle permissions
        dictator.setPermission(settle, settle.settle.selector, address(sequencerRouter));
        dictator.setPermission(settle, settle.collectAllocationAccountDust.selector, address(sequencerRouter));

        // Mirror permissions
        dictator.setPermission(mirror, mirror.requestOpen.selector, address(sequencerRouter));
        dictator.setPermission(mirror, mirror.requestAdjust.selector, address(sequencerRouter));
        dictator.setPermission(mirror, mirror.requestCloseStalled.selector, address(sequencerRouter));
        dictator.setPermission(mirror, mirror.execute.selector, address(sequencerRouter));
        dictator.setPermission(mirror, mirror.liquidate.selector, address(sequencerRouter));

        // GMX callback permissions for SequencerRouter
        console.log("Setting up GMX callback permissions...");
        dictator.setPermission(sequencerRouter, sequencerRouter.afterOrderExecution.selector, Const.gmxOrderHandler);
        dictator.setPermission(sequencerRouter, sequencerRouter.afterOrderCancellation.selector, Const.gmxOrderHandler);
        dictator.setPermission(sequencerRouter, sequencerRouter.afterOrderFrozen.selector, Const.gmxOrderHandler);
        dictator.setPermission(sequencerRouter, sequencerRouter.refundExecutionFee.selector, Const.gmxOrderHandler);

        // Additional GMX handler permissions
        dictator.setPermission(
            sequencerRouter, sequencerRouter.afterOrderExecution.selector, Const.gmxLiquidationHandler
        );
        dictator.setPermission(sequencerRouter, sequencerRouter.afterOrderExecution.selector, Const.gmxAdlHandler);

        // Self-permission for refund
        dictator.setPermission(sequencerRouter, sequencerRouter.refundExecutionFee.selector, address(sequencerRouter));

        // External sequencer permissions
        console.log("Setting up external sequencer permissions...");
        dictator.setPermission(sequencerRouter, sequencerRouter.requestOpen.selector, Const.sequencer);
        dictator.setPermission(sequencerRouter, sequencerRouter.requestAdjust.selector, Const.sequencer);
        dictator.setPermission(sequencerRouter, sequencerRouter.settleAllocation.selector, Const.sequencer);
        dictator.setPermission(sequencerRouter, sequencerRouter.collectAllocationAccountDust.selector, Const.sequencer);

        // Initialize contract
        dictator.registerContract(sequencerRouter);
        console.log("SequencerRouter initialized and permissions configured");

        return sequencerRouter;
    }

    function setupCrossContractPermissions(Mirror mirror, Rule ruleContract) internal {
        console.log("\n--- Setting up cross-contract permissions ---");

        // Rule needs permission to initialize trader activity throttle via Mirror
        dictator.setPermission(mirror, mirror.initializeTraderActivityThrottle.selector, address(ruleContract));

        console.log("Cross-contract permissions configured");
    }

    function setupUpkeepingConfig(AccountContract account, Settle settle, SequencerRouter sequencerRouter) internal {
        console.log("\n--- Setting up upkeeping configuration ---");

        // Set up DAO permissions for configuration
        dictator.setPermission(account, account.setDepositCapList.selector, Const.dao);
        dictator.setPermission(settle, settle.setTokenDustThresholdList.selector, Const.dao);
        dictator.setPermission(sequencerRouter, sequencerRouter.recoverUnaccountedTokens.selector, Const.dao);

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

    function upgradeMirror() public {
        console.log("=== Upgrading Mirror Contract and SequencerRouter ===");

        AccountContract account = AccountContract(getDeployedAddress("Account"));
        Rule ruleContract = Rule(getDeployedAddress("Rule"));
        Settle settle = Settle(getDeployedAddress("Settle"));

        Mirror mirror = deployMirror(account);
        SequencerRouter sequencerRouter = deploySequencerRouter(mirror, ruleContract, settle, account);

        setupCrossContractPermissions(mirror, ruleContract);

        console.log("\n=== Mirror and SequencerRouter Upgrade Complete ===");
        console.log("New Mirror address:", address(mirror));
        console.log("New SequencerRouter address:", address(sequencerRouter));
        console.log("\nIMPORTANT: Update sequencer services to use the new SequencerRouter address");
    }
}
