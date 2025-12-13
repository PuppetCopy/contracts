// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.31;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {console} from "forge-std/src/console.sol";

import {MatchmakerRouter} from "src/MatchmakerRouter.sol";
import {UserRouter} from "src/UserRouter.sol";
import {Account as AccountContract} from "src/position/Account.sol";
import {Mirror} from "src/position/Mirror.sol";
import {Subscribe} from "src/position/Subscribe.sol";
import {Settle} from "src/position/Settle.sol";
import {IGmxExchangeRouter} from "src/position/interface/IGmxExchangeRouter.sol";
import {IGmxReadDataStore} from "src/position/interface/IGmxReadDataStore.sol";
import {AccountStore} from "src/shared/AccountStore.sol";
import {Dictatorship} from "src/shared/Dictatorship.sol";
import {FeeMarketplace} from "src/shared/FeeMarketplace.sol";
import {TokenRouter} from "src/shared/TokenRouter.sol";
import {MatchmakerRouterProxy} from "src/utils/MatchmakerRouterProxy.sol";
import {UserRouterProxy} from "src/utils/UserRouterProxy.sol";

import {BaseScript} from "./BaseScript.s.sol";
import {Const} from "./Const.sol";

contract DeployPosition is BaseScript {
    Dictatorship dictator = Dictatorship(getDeployedAddress("Dictatorship"));
    TokenRouter tokenRouter = TokenRouter(getDeployedAddress("TokenRouter"));

    function run() public {
        vm.startBroadcast(DEPLOYER_PRIVATE_KEY);

        // Deploy each contract with their permissions
        AccountStore accountStore = deployAccountStore();
        AccountContract account = deployAccount(accountStore);
        Subscribe subscribe = deploySubscribe();
        Mirror mirror = deployMirror(account);
        Settle settle = deploySettle(account);
        FeeMarketplace feeMarketplace = FeeMarketplace(getDeployedAddress("FeeMarketplace"));
        deployMatchmakerRouter(mirror, subscribe, settle, account, feeMarketplace);
        deployUserRouter(account, subscribe, mirror);
        setupCrossContractPermissions(mirror, subscribe);
        setupUpkeepingConfig(account, settle);

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
                platformSettleFeeFactor: 0.01e30,
                maxMatchmakerFeeToSettleRatio: 0.1e30,
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
        console.log("Settle initialized and permissions configfured");

        return settle;
    }

    function deploySubscribe() internal returns (Subscribe subscribe) {
        console.log("\n--- Deploying Subscribe Contract ---");

        // Deploy Subscribe contract
        subscribe = new Subscribe(
            dictator,
            Subscribe.Config({
                minExpiryDuration: 1 hours,
                minAllowanceRate: 100, // 1%
                maxAllowanceRate: 10000, // 100%
                minActivityThrottle: 1 hours,
                maxActivityThrottle: 30 days
            })
        );
        console.log("Subscribe deployed at:", address(subscribe));

        // Initialize contract
        dictator.registerContract(subscribe);
        console.log("Subscribe contract initialized and permissions configured");

        return subscribe;
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
                maxPuppetList: 200,
                maxMatchmakerFeeToAllocationRatio: 0.1e30,
                maxMatchmakerFeeToAdjustmentRatio: 0.1e30,
                maxMatchmakerFeeToCloseRatio: 0.1e30,
                maxMatchOpenDuration: 30 seconds,
                maxMatchAdjustDuration: 60 seconds,
                collateralReserveBps: 500
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

    function deployMatchmakerRouter(
        Mirror mirror,
        Subscribe subscribe,
        Settle settle,
        AccountContract account,
        FeeMarketplace feeMarketplace
    ) internal returns (MatchmakerRouterProxy) {
        console.log("\n--- Deploying MatchmakerRouter ---");

        MatchmakerRouterProxy matchmakerRouterProxy =
            MatchmakerRouterProxy(payable(getDeployedAddress("MatchmakerRouterProxy")));

        MatchmakerRouter matchmakerRouterImpl = new MatchmakerRouter(
            dictator,
            account,
            subscribe,
            mirror,
            settle,
            feeMarketplace,
            MatchmakerRouter.Config({
                feeReceiver: address(feeMarketplace.store()),
                // Gas limits from fork benchmark (testFork_GasBenchmark) + 20% buffer
                matchBaseGasLimit: 1_450_000, // measured: 1,201,011
                matchPerPuppetGasLimit: 31_000, // measured: 25,301
                adjustBaseGasLimit: 1_350_000, // estimated: matchBase - ~45k (no CREATE2)
                adjustPerPuppetGasLimit: 31_000, // same as match (similar per-puppet logic)
                settleBaseGasLimit: 115_000, // measured: 94,147
                settlePerPuppetGasLimit: 3_000, // measured: 2,469
                gasPriceBufferBasisPoints: 12000,
                // Time values in seconds (matchmaker multiplies by 1000 for ms)
                maxEthPriceAge: 300,
                maxIndexPriceAge: 3,
                maxFiatPriceAge: 60,
                maxGasAge: 2,
                stalledCheckInterval: 30,
                stalledPositionThreshold: 5 * 60,
                minMatchTraderCollateral: 25e30,
                minAllocationUsd: 20e30,
                minAdjustUsd: 10e30
            })
        );
        console.log("MatchmakerRouter implementation deployed at:", address(matchmakerRouterImpl));

        // Register implementation contract
        dictator.registerContract(matchmakerRouterImpl);

        // Set permissions on the PROXY address (stable address for matchmaker bots)
        console.log("Setting up Router permissions on proxy...");

        dictator.setPermission(settle, settle.settle.selector, address(matchmakerRouterProxy));
        dictator.setPermission(settle, settle.collectAllocationAccountDust.selector, address(matchmakerRouterProxy));
        dictator.setPermission(settle, settle.collectPlatformFees.selector, address(matchmakerRouterProxy));

        dictator.setPermission(mirror, mirror.matchmake.selector, address(matchmakerRouterProxy));
        dictator.setPermission(mirror, mirror.adjust.selector, address(matchmakerRouterProxy));
        dictator.setPermission(mirror, mirror.close.selector, address(matchmakerRouterProxy));

        dictator.setPermission(feeMarketplace, feeMarketplace.recordTransferIn.selector, address(matchmakerRouterProxy));

        // Update proxy to point to new implementation
        matchmakerRouterProxy.update(address(matchmakerRouterImpl));
        console.log("MatchmakerRouterProxy updated to implementation:", address(matchmakerRouterImpl));

        return matchmakerRouterProxy;
    }

    function setupCrossContractPermissions(Mirror mirror, Subscribe subscribe) internal {
        console.log("\n--- Setting up cross-contract permissions ---");

        // Subscribe needs permission to initialize trader activity throttle via Mirror
        dictator.setPermission(mirror, mirror.initializeTraderActivityThrottle.selector, address(subscribe));

        console.log("Cross-contract permissions configured");
    }

    function setupUpkeepingConfig(AccountContract account, Settle settle) internal {
        console.log("\n--- Setting up upkeeping configuration ---");

        dictator.setPermission(account, account.setDepositCapList.selector, Const.dao);
        dictator.setPermission(settle, settle.setTokenDustThresholdList.selector, Const.dao);
        dictator.setPermission(account, account.recoverUnaccountedTokens.selector, Const.dao);

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
        console.log("=== Upgrading Mirror Contract ===");

        AccountContract account = AccountContract(getDeployedAddress("Account"));
        Subscribe subscribe = Subscribe(getDeployedAddress("Subscribe"));
        Settle settle = Settle(getDeployedAddress("Settle"));
        FeeMarketplace feeMarketplace = FeeMarketplace(getDeployedAddress("FeeMarketplace"));

        Mirror mirror = deployMirror(account);
        MatchmakerRouterProxy matchmakerRouterProxy =
            deployMatchmakerRouter(mirror, subscribe, settle, account, feeMarketplace);
        setupCrossContractPermissions(mirror, subscribe);
        deployUserRouter(account, subscribe, mirror);

        console.log("\n=== Mirror Upgrade Complete ===");
        console.log("New Mirror address:", address(mirror));
        console.log("MatchmakerRouterProxy (stable):", address(matchmakerRouterProxy));
    }

    function upgradeSubscribe() public {
        console.log("=== Upgrading Subscribe Contract ===");

        AccountContract account = AccountContract(getDeployedAddress("Account"));
        Mirror mirror = Mirror(getDeployedAddress("Mirror"));
        Settle settle = Settle(getDeployedAddress("Settle"));
        FeeMarketplace feeMarketplace = FeeMarketplace(getDeployedAddress("FeeMarketplace"));

        Subscribe subscribe = deploySubscribe();
        MatchmakerRouterProxy matchmakerRouterProxy =
            deployMatchmakerRouter(mirror, subscribe, settle, account, feeMarketplace);
        setupCrossContractPermissions(mirror, subscribe);
        deployUserRouter(account, subscribe, mirror);

        console.log("\n=== Subscribe Upgrade Complete ===");
        console.log("New Subscribe address:", address(subscribe));
        console.log("MatchmakerRouterProxy (stable):", address(matchmakerRouterProxy));
    }

    function deployUserRouter(AccountContract account, Subscribe subscribe, Mirror mirror) internal {
        console.log("\n--- Deploying UserRouter ---");

        UserRouterProxy userRouterProxy = UserRouterProxy(payable(getDeployedAddress("UserRouterProxy")));
        FeeMarketplace feeMarketplace = FeeMarketplace(getDeployedAddress("FeeMarketplace"));

        // Set permissions on the PROXY address (stable address for users)
        dictator.setPermission(subscribe, subscribe.rule.selector, address(userRouterProxy));
        dictator.setPermission(account, account.deposit.selector, address(userRouterProxy));
        dictator.setPermission(account, account.withdraw.selector, address(userRouterProxy));
        dictator.setPermission(feeMarketplace, feeMarketplace.acceptOffer.selector, address(userRouterProxy));

        UserRouter userRouterImpl = new UserRouter(account, subscribe, feeMarketplace, mirror);

        // Note: UserRouter doesn't extend CoreContract, so no registerContract needed
        userRouterProxy.update(address(userRouterImpl));

        console.log("UserRouter implementation deployed at:", address(userRouterImpl));
        console.log("UserRouterProxy updated to implementation:", address(userRouterImpl));
    }
}
 
