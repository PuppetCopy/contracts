// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Test} from "forge-std/src/Test.sol";
// import {console2} from "forge-std/src/console2.sol";

import {Allocation} from "src/position/Allocation.sol";
import {MatchingRule} from "src/position/MatchingRule.sol";
import {MirrorPosition} from "src/position/MirrorPosition.sol";
import {KeeperRouter} from "src/keeperRouter.sol";
import {IGmxExchangeRouter} from "src/position/interface/IGmxExchangeRouter.sol";
import {GmxPositionUtils} from "src/position/utils/GmxPositionUtils.sol";
import {PositionUtils} from "src/position/utils/PositionUtils.sol";
import {AllocationStore} from "src/shared/AllocationStore.sol";
import {Dictatorship} from "src/shared/Dictatorship.sol";
import {FeeMarketplace} from "src/shared/FeeMarketplace.sol";
import {FeeMarketplaceStore} from "src/shared/FeeMarketplaceStore.sol";
import {TokenRouter} from "src/shared/TokenRouter.sol";
import {PuppetToken} from "src/tokenomics/PuppetToken.sol";
import {Error} from "src/utils/Error.sol";

import {Const} from "script/Const.sol";

/**
 * @title Trading Fork Test
 * @notice Fork tests using real Arbitrum contracts and state
 * @dev Tests integration with live GMX contracts on Arbitrum
 */
contract TradingForkTest is Test {
    // Real Arbitrum addresses
    IERC20 constant USDC = IERC20(Const.usdc);
    IERC20 constant WETH = IERC20(Const.wnt);

    // Real GMX contracts on Arbitrum
    IGmxExchangeRouter constant GMX_EXCHANGE_ROUTER = IGmxExchangeRouter(0x7C68C7866A64FA2160F78EEaE12217FFbf871fa8);
    address constant GMX_ORDER_VAULT = 0x31eF83a530Fde1B38EE9A18093A333D8Bbbc40D5;
    address constant GMX_READER = 0x60a0fF4cDaF0f6D496d71e0bC0fFa86FE8E6B23c;

    // Test contracts
    Dictatorship dictator;
    TokenRouter tokenRouter;
    PuppetToken puppetToken;
    AllocationStore allocationStore;
    Allocation allocation;
    MatchingRule matchingRule;
    FeeMarketplace feeMarketplace;
    FeeMarketplaceStore feeMarketplaceStore;
    MirrorPosition mirrorPosition;
    KeeperRouter keeperRouter;

    // Test users
    address owner = makeAddr("owner");
    address trader = makeAddr("trader");
    address puppet1 = makeAddr("puppet1");
    address puppet2 = makeAddr("puppet2");
    address keeper = makeAddr("keeper");

    // Test parameters
    uint constant FORK_BLOCK = 340881246; // Arbitrum block with good liquidity

    function setUp() public {
        // Fork Arbitrum at specific block
        vm.createSelectFork(vm.envString("RPC_URL"));
        vm.rollFork(FORK_BLOCK);

        vm.startPrank(owner);
        vm.deal(owner, 100 ether);

        // Deploy core contracts
        dictator = new Dictatorship(owner);
        tokenRouter = new TokenRouter(dictator, TokenRouter.Config(200_000));
        dictator.initContract(tokenRouter);
        puppetToken = new PuppetToken();

        // Deploy position contracts
        feeMarketplaceStore = new FeeMarketplaceStore(dictator, tokenRouter, puppetToken);
        feeMarketplace = new FeeMarketplace(
            dictator,
            puppetToken,
            feeMarketplaceStore,
            FeeMarketplace.Config({
                distributionTimeframe: 1 days,
                burnBasisPoints: 5000 // 50% burn
            })
        );

        allocationStore = new AllocationStore(dictator, tokenRouter);
        
        allocation = new Allocation(
            dictator,
            allocationStore,
            Allocation.Config({
                platformSettleFeeFactor: 0.05e30, // 5%
                maxKeeperFeeToCollectDustRatio: 0.1e30, // 10%
                maxPuppetList: 50,
                maxKeeperFeeToAllocationRatio: 0.1e30, // 10%
                maxKeeperFeeToAdjustmentRatio: 0.1e30, // 10%
                gmxOrderVault: GMX_ORDER_VAULT,
                allocationAccountTransferGasLimit: 100000
            })
        );

        matchingRule = new MatchingRule(
            dictator,
            allocationStore,
            MatchingRule.Config({
                minExpiryDuration: 1 hours,
                minAllowanceRate: 100, // 1%
                maxAllowanceRate: 10000, // 100%
                minActivityThrottle: 1 hours,
                maxActivityThrottle: 30 days
            })
        );

        mirrorPosition = new MirrorPosition(
            dictator,
            MirrorPosition.Config({
                gmxExchangeRouter: GMX_EXCHANGE_ROUTER,
                gmxOrderVault: GMX_ORDER_VAULT,
                referralCode: bytes32("PUPPET"),
                increaseCallbackGasLimit: 2000000,
                decreaseCallbackGasLimit: 2000000,
                refundExecutionFeeReceiver: owner
            })
        );

        keeperRouter = new KeeperRouter(
            dictator,
            mirrorPosition,
            matchingRule,
            feeMarketplace,
            allocation
        );

        // Set up permissions
        dictator.setAccess(allocationStore, address(allocation));
        dictator.setAccess(allocationStore, address(matchingRule));
        dictator.setAccess(allocationStore, address(keeperRouter));
        
        dictator.setPermission(tokenRouter, tokenRouter.transfer.selector, address(allocationStore));
        dictator.setPermission(keeperRouter, keeperRouter.requestMirror.selector, keeper);
        dictator.setPermission(keeperRouter, keeperRouter.requestAdjust.selector, keeper);
        dictator.setPermission(keeperRouter, keeperRouter.settle.selector, keeper);
        dictator.setPermission(matchingRule, matchingRule.setTokenAllowanceList.selector, owner);

        // Initialize contracts
        dictator.initContract(feeMarketplace);
        dictator.initContract(allocation);
        dictator.initContract(matchingRule);
        
        // Configure MatchingRule with token allowances
        IERC20[] memory allowedTokens = new IERC20[](2);
        allowedTokens[0] = USDC;
        allowedTokens[1] = WETH;
        uint[] memory allowanceCaps = new uint[](2);
        allowanceCaps[0] = 1000000e6; // 1M USDC cap
        allowanceCaps[1] = 1000e18;   // 1000 WETH cap
        matchingRule.setTokenAllowanceList(allowedTokens, allowanceCaps);
        
        dictator.initContract(mirrorPosition);
        dictator.initContract(keeperRouter);

        // Fund test accounts with real tokens from Arbitrum whales
        _fundTestAccounts();
        
        // Set up puppet trading rules
        _setupTradingRules();

        vm.stopPrank();
    }

    function _fundTestAccounts() internal {
        // Find USDC whale and fund test accounts
        address usdcWhale = 0x2Df1c51E09aECF9cacB7bc98cB1742757f163dF7; // Arbitrum USDC whale
        
        vm.startPrank(usdcWhale);
        USDC.transfer(puppet1, 50000e6); // 50k USDC
        USDC.transfer(puppet2, 30000e6); // 30k USDC
        USDC.transfer(keeper, 10000e6);  // 10k USDC for fees
        vm.stopPrank();

        // Fund with ETH for execution fees
        vm.deal(puppet1, 10 ether);
        vm.deal(puppet2, 10 ether);
        vm.deal(keeper, 10 ether);
        vm.deal(trader, 1 ether);

        // Give test contract access to allocation store for setup
        dictator.setAccess(allocationStore, address(this));
        
        // Deposit puppet funds into allocation store
        vm.startPrank(puppet1);
        USDC.approve(address(tokenRouter), type(uint).max);
        vm.stopPrank();
        allocationStore.transferIn(USDC, puppet1, 25000e6);

        vm.startPrank(puppet2);
        USDC.approve(address(tokenRouter), type(uint).max);
        vm.stopPrank();
        allocationStore.transferIn(USDC, puppet2, 15000e6);
    }

    function _setupTradingRules() internal {
        // Set up trading rules for puppets
        vm.startPrank(puppet1);
        matchingRule.setRule(
            allocation,
            USDC,
            puppet1,
            trader,
            MatchingRule.Rule({
                allowanceRate: 2000, // 20%
                throttleActivity: 10 minutes,
                expiry: block.timestamp + 30 days
            })
        );
        vm.stopPrank();

        vm.startPrank(puppet2);
        matchingRule.setRule(
            allocation,
            USDC,
            puppet2,
            trader,
            MatchingRule.Rule({
                allowanceRate: 1500, // 15%
                throttleActivity: 10 minutes,
                expiry: block.timestamp + 30 days
            })
        );
        vm.stopPrank();
    }

    function testForkEnvironmentSetup() public {
        // Verify fork setup is correct
        assertEq(block.chainid, 42161, "Should be on Arbitrum");
        assertEq(block.number, FORK_BLOCK, "Should be at correct fork block");
        
        // Verify real token balances
        assertGt(USDC.balanceOf(puppet1), 0, "Puppet1 should have USDC");
        assertGt(USDC.balanceOf(puppet2), 0, "Puppet2 should have USDC");
        
        // Verify allocation store balances
        assertEq(allocationStore.userBalanceMap(USDC, puppet1), 25000e6, "Puppet1 allocation balance");
        assertEq(allocationStore.userBalanceMap(USDC, puppet2), 15000e6, "Puppet2 allocation balance");
        
        // Console logs removed due to compilation conflicts
        // console2.log("Fork test environment setup successfully");
    }

    function testRealGmxIntegration() public {
        // Test that we can interact with real GMX contracts
        address[] memory puppetList = new address[](2);
        puppetList[0] = puppet1;
        puppetList[1] = puppet2;

        uint allocationId = 1;
        uint keeperFee = 10e6; // 10 USDC

        Allocation.AllocationParams memory allocParams = Allocation.AllocationParams({
            collateralToken: USDC,
            trader: trader,
            puppetList: puppetList,
            allocationId: allocationId,
            keeperFee: keeperFee,
            keeperFeeReceiver: keeper
        });

        // Use real WETH market on Arbitrum
        address wethMarket = 0x70d95587d40A2caf56bd97485aB3Eec10Bee6336; // Real WETH market

        MirrorPosition.CallPosition memory callParams = MirrorPosition.CallPosition({
            collateralToken: USDC,
            trader: trader,
            market: wethMarket,
            isIncrease: true,
            isLong: true,
            executionFee: 0.002 ether, // Higher execution fee for mainnet
            collateralDelta: 1000e30,
            sizeDeltaInUsd: 5000e30,
            acceptablePrice: 4000e30, // $4000 per ETH
            triggerPrice: 0
        });

        // Execute mirror request
        vm.prank(keeper);
        vm.deal(keeper, 1 ether);
        
        (address allocationAddress, bytes32 requestKey) = keeperRouter.requestMirror{value: 0.002 ether}(
            allocParams,
            callParams
        );

        // Verify request was submitted to real GMX
        assertNotEq(requestKey, bytes32(0), "Should generate real GMX request key");
        assertNotEq(allocationAddress, address(0), "Should create allocation address");
        
        // Verify keeper fee was paid
        assertEq(USDC.balanceOf(keeper), 10000e6 + keeperFee, "Keeper should receive fee");

        // console2.log("Successfully submitted order to real GMX");
    }

    function testRealTokenTransfers() public {
        // Test transfers with real tokens (fee-on-transfer protection)
        uint initialBalance = USDC.balanceOf(address(allocationStore));
        
        // Transfer USDC to allocation store
        vm.prank(puppet1);
        USDC.transfer(address(allocationStore), 1000e6);
        
        // Record the transfer (this should handle any fee-on-transfer)
        uint recordedAmount = allocationStore.recordTransferIn(USDC);
        
        // Verify accounting is correct
        uint finalBalance = USDC.balanceOf(address(allocationStore));
        uint actualTransferred = finalBalance - initialBalance;
        
        assertEq(recordedAmount, actualTransferred, "Recorded amount should match actual transfer");
        assertLe(actualTransferred, 1000e6, "Actual transfer should be <= intended (fee-on-transfer)");
        
        // console2.log("Intended transfer:", 1000e6);
    }

    // Helper function to skip if no RPC URL is set
    modifier skipIfNoRPC() {
        try vm.envString("RPC_URL") returns (string memory) {
            _;
        } catch {
            // console2.log("Skipping fork test - no RPC_URL environment variable set");
        }
    }
}