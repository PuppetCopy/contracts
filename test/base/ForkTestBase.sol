// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Test} from "forge-std/src/Test.sol";
import {console} from "forge-std/src/console.sol";

import {UserRouter} from "src/UserRouter.sol";
import {KeeperRouter} from "src/keeperRouter.sol";
import {Rule} from "src/position/Rule.sol";
import {Deposit} from "src/position/Deposit.sol";
import {Mirror} from "src/position/Mirror.sol";
import {Settle} from "src/position/Settle.sol";
import {IGmxExchangeRouter} from "src/position/interface/IGmxExchangeRouter.sol";
import {IGmxReadDataStore} from "src/position/interface/IGmxReadDataStore.sol";
import {AllocationStore} from "src/shared/AllocationStore.sol";
import {Dictatorship} from "src/shared/Dictatorship.sol";
import {FeeMarketplace} from "src/shared/FeeMarketplace.sol";
import {FeeMarketplaceStore} from "src/shared/FeeMarketplaceStore.sol";
import {TokenRouter} from "src/shared/TokenRouter.sol";
import {PuppetToken} from "src/tokenomics/PuppetToken.sol";

import {Const} from "script/Const.sol";

/**
 * @title ForkTestBase
 * @notice Base contract for fork tests with common contract deployment and setup
 * @dev Provides standardized deployment, permissions, and funding for fork tests
 */
abstract contract ForkTestBase is Test {
    // Real Arbitrum addresses
    IERC20 constant USDC = IERC20(Const.usdc);
    IERC20 constant WETH = IERC20(Const.wnt);

    // System contracts
    Dictatorship public dictator;
    TokenRouter public tokenRouter;
    PuppetToken public puppetToken;
    AllocationStore public allocationStore;
    FeeMarketplace public feeMarketplace;
    FeeMarketplaceStore public feeMarketplaceStore;
    // Note: Allocate functionality has been merged into Mirror
    Settle public settle;
    Rule public ruleContract;
    Deposit public depositContract;
    Mirror public mirror;
    KeeperRouter public keeperRouter;
    UserRouter public userRouter;

    // Test accounts
    address public owner = makeAddr("owner");
    address public trader = makeAddr("trader");
    address public puppet1 = makeAddr("puppet1");
    address public puppet2 = makeAddr("puppet2");
    address public keeper = makeAddr("keeper");

    // USDC whale for funding
    address constant USDC_WHALE = 0x2Df1c51E09aECF9cacB7bc98cB1742757f163dF7;

    // Setup flags
    bool public isSetupComplete;
    bool public isRPCAvailable;

    /**
     * @notice Initializes fork test environment
     * @dev Call this from test setUp() function
     */
    function initializeForkTest() internal {
        // Check RPC availability
        string memory rpcUrl;
        try vm.envString("RPC_URL") returns (string memory url) {
            rpcUrl = url;
            isRPCAvailable = true;
        } catch {
            console.log("Fork Test: Skipping - no RPC_URL environment variable");
            isRPCAvailable = false;
            return;
        }

        // Fork Arbitrum at current block
        vm.createSelectFork(rpcUrl);

        console.log("=== Fork Test Setup ===");
        console.log("Chain ID:", block.chainid);
        console.log("Block Number:", block.number);
        console.log("Block Timestamp:", block.timestamp);

        vm.startPrank(owner);
        vm.deal(owner, 100 ether);

        // Deploy and configure system
        _deployContracts();
        _setupPermissions();
        _initializeContracts();
        _configureSystem();

        vm.stopPrank();

        isSetupComplete = true;
        console.log("=== Setup Complete ===");
    }

    /**
     * @notice Funds test accounts with tokens and ETH
     * @param puppet1Balance USDC balance for puppet1
     * @param puppet2Balance USDC balance for puppet2
     * @param puppet1Deposit USDC deposit amount for puppet1
     * @param puppet2Deposit USDC deposit amount for puppet2
     */
    function fundTestAccounts(
        uint puppet1Balance,
        uint puppet2Balance,
        uint puppet1Deposit,
        uint puppet2Deposit
    ) internal {
        require(isSetupComplete, "Setup not complete");
        require(USDC.balanceOf(USDC_WHALE) >= puppet1Balance + puppet2Balance + 10000e6, "Whale insufficient balance");

        // Transfer USDC from whale
        vm.startPrank(USDC_WHALE);
        USDC.transfer(puppet1, puppet1Balance);
        USDC.transfer(puppet2, puppet2Balance);
        USDC.transfer(keeper, 10000e6);
        vm.stopPrank();

        // Fund with ETH
        vm.deal(puppet1, 10 ether);
        vm.deal(puppet2, 10 ether);
        vm.deal(keeper, 10 ether);
        vm.deal(trader, 1 ether);

        // Users deposit through UserRouter
        vm.prank(puppet1);
        USDC.approve(address(tokenRouter), puppet1Deposit);
        vm.prank(puppet1);
        userRouter.deposit(USDC, puppet1Deposit);

        vm.prank(puppet2);
        USDC.approve(address(tokenRouter), puppet2Deposit);
        vm.prank(puppet2);
        userRouter.deposit(USDC, puppet2Deposit);
    }

    /**
     * @notice Sets up trading rules for puppets
     * @param puppet1Rate Allowance rate for puppet1 (basis points)
     * @param puppet2Rate Allowance rate for puppet2 (basis points)
     * @param throttlePeriod Activity throttle period in seconds
     * @param expiryPeriod Rule expiry period in seconds
     */
    function setupTradingRules(uint puppet1Rate, uint puppet2Rate, uint throttlePeriod, uint expiryPeriod) internal {
        require(isSetupComplete, "Setup not complete");

        vm.prank(puppet1);
        userRouter.setMatchingRule(
            USDC,
            trader,
            Rule.RuleParams({
                allowanceRate: puppet1Rate,
                throttleActivity: throttlePeriod,
                expiry: block.timestamp + expiryPeriod
            })
        );

        vm.prank(puppet2);
        userRouter.setMatchingRule(
            USDC,
            trader,
            Rule.RuleParams({
                allowanceRate: puppet2Rate,
                throttleActivity: throttlePeriod,
                expiry: block.timestamp + expiryPeriod
            })
        );
    }

    /**
     * @notice Checks if RPC is available for fork testing
     */
    function skipIfNoRPC() internal view {
        if (!isRPCAvailable) {
            console.log("Test: Skipping - RPC not available");
            return;
        }
    }

    // Internal deployment functions
    function _deployContracts() private {
        dictator = new Dictatorship(owner);
        tokenRouter = new TokenRouter(dictator, TokenRouter.Config(200_000));
        puppetToken = new PuppetToken(owner);

        allocationStore = new AllocationStore(dictator, tokenRouter);
        feeMarketplaceStore = new FeeMarketplaceStore(dictator, tokenRouter, puppetToken);

        feeMarketplace = new FeeMarketplace(
            dictator,
            puppetToken,
            feeMarketplaceStore,
            FeeMarketplace.Config({
                transferOutGasLimit: 200_000,
                distributionTimeframe: 7 days,
                burnBasisPoints: 5000 // 50%
            })
        );

        // Note: Allocate functionality has been merged into Mirror

        settle = new Settle(
            dictator,
            allocationStore,
            Settle.Config({
                transferOutGasLimit: 200_000,
                platformSettleFeeFactor: 0.01e30,
                maxKeeperFeeToSettleRatio: 0.1e30,
                maxPuppetList: 50,
                allocationAccountTransferGasLimit: 100_000
            })
        );

        ruleContract = new Rule(
            dictator,
            Rule.Config({
                minExpiryDuration: 1 hours,
                minAllowanceRate: 100,
                maxAllowanceRate: 10000,
                minActivityThrottle: 1 hours,
                maxActivityThrottle: 30 days
            })
        );

        depositContract = new Deposit(
            dictator,
            allocationStore,
            Deposit.Config({
                transferOutGasLimit: 200_000
            })
        );

        mirror = new Mirror(
            dictator,
            allocationStore,
            Mirror.Config({
                gmxExchangeRouter: IGmxExchangeRouter(Const.gmxExchangeRouter),
                gmxDataStore: IGmxReadDataStore(Const.gmxDataStore),
                gmxOrderVault: Const.gmxOrderVault,
                referralCode: bytes32("PUPPET"),
                increaseCallbackGasLimit: 2e6,
                decreaseCallbackGasLimit: 2e6,
                fallbackRefundExecutionFeeReceiver: owner,
                transferOutGasLimit: 200_000,
                maxPuppetList: 50,
                maxKeeperFeeToAllocationRatio: 0.1e30,
                maxKeeperFeeToAdjustmentRatio: 0.1e30
            })
        );

        // Debug: Log the config we're passing to constructor
        console.log("\\n--- Debug: Updated empirical gas config ---");
        console.log("mirrorBaseGas: 1283731 (empirically measured)");
        console.log("mirrorPerPuppetGas: 30000 (conservative estimate)");
        console.log("adjustBaseGas: 910663 (needs empirical measurement)");
        console.log("adjustPerPuppetGas: 3412 (needs empirical measurement)");
        console.log("settleBaseGas: 90847 (empirically measured)");
        console.log("settlePerPuppetGas: 15000 (empirically measured)");

        keeperRouter = new KeeperRouter(
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
                fallbackRefundExecutionFeeReceiver: owner
            })
        );
        userRouter = new UserRouter(depositContract, ruleContract, feeMarketplace, mirror);
    }

    function _setupPermissions() private {
        // Store access
        // Note: allocate access moved to mirrorPosition
        dictator.setAccess(allocationStore, address(settle));
        dictator.setAccess(allocationStore, address(depositContract));
        dictator.setAccess(allocationStore, address(mirror));

        // Core permissions
        dictator.setPermission(tokenRouter, tokenRouter.transfer.selector, address(allocationStore));
        dictator.setPermission(
            mirror, mirror.initializeTraderActivityThrottle.selector, address(ruleContract)
        );

        // UserRouter permissions
        dictator.setPermission(depositContract, depositContract.deposit.selector, address(userRouter));
        dictator.setPermission(depositContract, depositContract.withdraw.selector, address(userRouter));
        dictator.setPermission(ruleContract, ruleContract.setRule.selector, address(userRouter));
        dictator.setPermission(feeMarketplace, feeMarketplace.acceptOffer.selector, address(userRouter));

        // KeeperRouter permissions
        // Note: createAllocation and collectKeeperFee functionality merged into Mirror
        dictator.setPermission(settle, settle.settle.selector, address(keeperRouter));
        dictator.setPermission(settle, settle.collectDust.selector, address(keeperRouter));
        dictator.setPermission(mirror, mirror.requestOpen.selector, address(keeperRouter));
        dictator.setPermission(mirror, mirror.requestAdjust.selector, address(keeperRouter));
        dictator.setPermission(mirror, mirror.execute.selector, address(keeperRouter));
        dictator.setPermission(mirror, mirror.liquidate.selector, address(keeperRouter));

        // External permissions
        dictator.setPermission(keeperRouter, keeperRouter.requestOpen.selector, keeper);
        dictator.setPermission(keeperRouter, keeperRouter.requestAdjust.selector, keeper);
        dictator.setPermission(keeperRouter, keeperRouter.settleAllocation.selector, keeper);
        dictator.setPermission(keeperRouter, keeperRouter.collectDust.selector, keeper);
        dictator.setPermission(keeperRouter, keeperRouter.refundExecutionFee.selector, address(keeperRouter));

        // Admin permissions
        dictator.setPermission(depositContract, depositContract.setTokenAllowanceList.selector, owner);
        dictator.setPermission(settle, settle.setTokenDustThresholdList.selector, owner);
    }

    function _initializeContracts() private {
        dictator.registerContract(tokenRouter);
        dictator.registerContract(feeMarketplace);
        // Note: allocate functionality merged into mirrorPosition
        dictator.registerContract(settle);
        dictator.registerContract(ruleContract);
        dictator.registerContract(depositContract);
        dictator.registerContract(mirror);
        dictator.registerContract(keeperRouter);
    }

    function _configureSystem() private {
        // Configure allowed tokens
        IERC20[] memory allowedTokens = new IERC20[](1);
        allowedTokens[0] = USDC;
        uint[] memory allowanceCaps = new uint[](1);
        allowanceCaps[0] = 1000000e6; // 1M USDC cap
        depositContract.setTokenAllowanceList(allowedTokens, allowanceCaps);

        // Set dust thresholds
        IERC20[] memory dustTokens = new IERC20[](1);
        dustTokens[0] = USDC;
        uint[] memory dustThresholds = new uint[](1);
        dustThresholds[0] = 10e6; // 10 USDC dust threshold
        settle.setTokenDustThresholdList(dustTokens, dustThresholds);
    }
}
