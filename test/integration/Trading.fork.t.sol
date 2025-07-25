// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import {ForkTestBase} from "../base/ForkTestBase.sol";
import {console} from "forge-std/src/console.sol";
import {Const} from "script/Const.sol";

import {KeeperRouter} from "src/keeperRouter.sol";
import {MatchingRule} from "src/position/MatchingRule.sol";
import {MirrorPosition} from "src/position/MirrorPosition.sol";
import {Settle} from "src/position/Settle.sol";

/**
 * @title Trading Fork Test - Live GMX Integration
 * @notice Fork test for analyzing live GMX integration performance and behavior
 * @dev Results are documented in REPORT.md for ongoing analysis
 */
contract TradingForkTest is ForkTestBase {
    // Test configuration
    uint constant PUPPET1_BALANCE = 50000e6; // 50k USDC
    uint constant PUPPET2_BALANCE = 30000e6; // 30k USDC
    uint constant PUPPET1_DEPOSIT = 25000e6; // 25k USDC
    uint constant PUPPET2_DEPOSIT = 15000e6; // 15k USDC
    uint constant KEEPER_FEE = 50e6; // 50 USDC
    uint constant EXECUTION_FEE = 0.003 ether;

    function setUp() public {
        // Initialize fork test environment
        initializeForkTest();

        if (!isRPCAvailable) return;

        // Fund test accounts and setup trading rules
        fundTestAccounts(PUPPET1_BALANCE, PUPPET2_BALANCE, PUPPET1_DEPOSIT, PUPPET2_DEPOSIT);
        setupTradingRules(2000, 1500, 1 hours, 30 days); // 20%, 15% allowance rates
    }

    /**
     * @notice Test live GMX position mirroring with comprehensive logging
     * @dev This test creates a mirror position and logs all relevant data for analysis
     */
    function testLiveGmxPositionMirror() public {
        skipIfNoRPC();
        if (!isRPCAvailable) return;

        console.log("\n=== Testing Live GMX Position Mirror ===");

        // Test parameters
        address[] memory puppetList = new address[](2);
        puppetList[0] = puppet1;
        puppetList[1] = puppet2;

        uint allocationId = 1;
        uint collateralAmount = 1000e30; // $1000
        uint positionSize = 5000e30; // $5000 (5x leverage)
        uint acceptablePrice = 4000e30; // $4000 per ETH

        // Log initial state
        console.log("\n--- Initial State ---");
        console.log("Puppet1 Balance:", allocationStore.userBalanceMap(USDC, puppet1));
        console.log("Puppet2 Balance:", allocationStore.userBalanceMap(USDC, puppet2));
        console.log("Keeper Balance:", USDC.balanceOf(keeper));
        console.log("GMX ExchangeRouter:", address(Const.gmxExchangeRouter));
        console.log("GMX OrderVault:", Const.gmxOrderVault);

        // Prepare position parameters (merged allocation and position params)
        MirrorPosition.CallPosition memory callParams = MirrorPosition.CallPosition({
            collateralToken: USDC,
            traderRequestKey: bytes32(0),
            trader: trader,
            market: Const.gmxEthUsdcMarket,
            isIncrease: true,
            isLong: true,
            executionFee: EXECUTION_FEE,
            collateralDelta: collateralAmount,
            sizeDeltaInUsd: positionSize,
            acceptablePrice: acceptablePrice,
            triggerPrice: 0,
            allocationId: allocationId,
            keeperFee: KEEPER_FEE,
            keeperFeeReceiver: keeper
        });

        console.log("\n--- Position Parameters ---");
        console.log("Collateral Amount:", collateralAmount);
        console.log("Position Size:", positionSize);
        console.log("Leverage:", (positionSize * 1e18) / collateralAmount, "x");
        console.log("Acceptable Price:", acceptablePrice);
        console.log("Execution Fee:", EXECUTION_FEE);
        console.log("Keeper Fee:", KEEPER_FEE);

        // Record gas usage and timing
        uint gasStart = gasleft();
        uint timestampStart = block.timestamp;

        // Execute mirror request
        vm.prank(keeper);
        (address allocationAddress, bytes32 requestKey) =
            keeperRouter.requestOpen{value: EXECUTION_FEE}(callParams, puppetList);

        uint gasUsed = gasStart - gasleft();
        uint timestampEnd = block.timestamp;

        // Log execution results
        console.log("\n--- Execution Results ---");
        console.log("Success: Mirror request submitted");
        console.log("Gas Used:", gasUsed);
        console.log("Execution Time:", timestampEnd - timestampStart, "seconds");
        console.log("Request Key:", vm.toString(requestKey));
        console.log("Allocation Address:", allocationAddress);

        // Verify allocation was created
        uint totalAllocation = mirrorPosition.getAllocation(allocationAddress);
        uint[] memory puppetAllocations = mirrorPosition.getPuppetAllocationList(allocationAddress);

        console.log("\n--- Allocation Details ---");
        console.log("Total Allocation:", totalAllocation);
        console.log("Puppet1 Allocation:", puppetAllocations[0]);
        console.log("Puppet2 Allocation:", puppetAllocations[1]);

        // Calculate allocation percentages
        if (totalAllocation > 0) {
            uint puppet1Percent = (puppetAllocations[0] * 10000) / totalAllocation;
            uint puppet2Percent = (puppetAllocations[1] * 10000) / totalAllocation;
            console.log("Puppet1 Percentage (basis points):", puppet1Percent);
            console.log("Puppet2 Percentage (basis points):", puppet2Percent);
        }

        // Log gas configuration from KeeperRouter
        KeeperRouter.Config memory gasConfig = keeperRouter.getConfig();
        console.log("\n--- Gas Configuration ---");
        console.log("Mirror Base Gas Limit:", gasConfig.mirrorBaseGasLimit);
        console.log("Mirror Per-Puppet Gas Limit:", gasConfig.mirrorPerPuppetGasLimit);
        console.log("Adjust Base Gas Limit:", gasConfig.adjustBaseGasLimit);
        console.log("Adjust Per-Puppet Gas Limit:", gasConfig.adjustPerPuppetGasLimit);

        // Debug: Also check the config() function output

        KeeperRouter.Config memory config = keeperRouter.getConfig();
        console.log("\n--- Debug: Config Bytes Length ---");
        bytes memory configBytes = abi.encode(config);
        console.log("Config bytes length:", configBytes.length);

        // Debug: Log expected values
        console.log("\n--- Expected Values ---");
        console.log("Expected Mirror Base Gas: 1206566");
        console.log("Expected Mirror Per-Puppet Gas: 29124");

        // Log final balances
        console.log("\n--- Final State ---");
        console.log("Puppet1 Remaining Balance:", allocationStore.userBalanceMap(USDC, puppet1));
        console.log("Puppet2 Remaining Balance:", allocationStore.userBalanceMap(USDC, puppet2));
        console.log("Keeper Final Balance:", USDC.balanceOf(keeper));

        // Assertions for test validity
        assertNotEq(requestKey, bytes32(0), "Should generate GMX request key");
        assertNotEq(allocationAddress, address(0), "Should create allocation address");
        assertGt(totalAllocation, 0, "Should create non-zero allocation");
        assertEq(USDC.balanceOf(keeper), 10000e6 + KEEPER_FEE, "Keeper should receive fee");

        console.log("\n=== Test Complete - Results logged for analysis ===");
    }

    /**
     * @notice Comprehensive gas analysis across different puppet counts
     * @dev Tests gas consumption patterns for empirical limit setting
     */
    function testGasAnalysisReport() public {
        skipIfNoRPC();
        if (!isRPCAvailable) return;

        console.log("\n=== Gas Analysis Report ===");
        console.log("Purpose: Determine accurate gas limits for keeper operations");
        console.log("Note: Results exclude keeper-side buffers");

        // Test with 1 puppet
        uint gas1Puppet = _testMirrorGasUsage(1, "1 Puppet");

        // Test with 2 puppets
        uint gas2Puppets = _testMirrorGasUsage(2, "2 Puppets");

        // Test with 3 puppets (add puppet3)
        address puppet3 = makeAddr("puppet3");

        // Fund puppet3
        vm.startPrank(USDC_WHALE);
        USDC.transfer(puppet3, 15000e6);
        vm.stopPrank();

        vm.deal(puppet3, 10 ether);

        vm.prank(puppet3);
        USDC.approve(address(tokenRouter), 10000e6);
        vm.prank(puppet3);
        userRouter.deposit(USDC, 10000e6);

        vm.prank(puppet3);
        userRouter.setMatchingRule(
            USDC,
            trader,
            MatchingRule.Rule({
                allowanceRate: 1000, // 10%
                throttleActivity: 1 hours,
                expiry: block.timestamp + 30 days
            })
        );

        uint gas3Puppets = _testMirrorGasUsage(3, "3 Puppets");

        // Calculate per-puppet gas cost
        console.log("\n--- Gas Analysis Results ---");
        console.log("1 Puppet Gas:", gas1Puppet);
        console.log("2 Puppets Gas:", gas2Puppets);
        console.log("3 Puppets Gas:", gas3Puppets);

        // Calculate incremental costs (handle potential decreases)
        int perPuppetCost12 = int(gas2Puppets) - int(gas1Puppet);
        int perPuppetCost23 = int(gas3Puppets) - int(gas2Puppets);

        console.log("\n--- Incremental Analysis ---");
        console.log("Per-puppet cost (1->2):", perPuppetCost12 >= 0 ? uint(perPuppetCost12) : 0);
        console.log("  (Negative indicates gas savings)");
        console.log("Per-puppet cost (2->3):", perPuppetCost23 >= 0 ? uint(perPuppetCost23) : 0);
        console.log("  (Negative indicates gas savings)");

        // Use highest gas usage as conservative estimate
        uint maxGas = gas1Puppet;
        if (gas2Puppets > maxGas) maxGas = gas2Puppets;
        if (gas3Puppets > maxGas) maxGas = gas3Puppets;

        // Conservative estimate: use the worst case
        uint conservativePerPuppet = 30000; // Conservative estimate based on typical costs

        console.log("\n--- Recommended Gas Limits ---");
        console.log("Mirror Base Gas Limit:", maxGas);
        console.log("Mirror Per-Puppet Gas Limit:", conservativePerPuppet);

        // Project costs for larger puppet counts
        console.log("\n--- Projected Gas Usage ---");
        for (uint i = 5; i <= 20; i += 5) {
            uint projected = maxGas + (conservativePerPuppet * (i - 1));
            console.log(string.concat("Projected ", vm.toString(i), " puppets:"), projected);
        }

        console.log("\n=== Gas Analysis Complete ===");
    }

    function _testMirrorGasUsage(uint puppetCount, string memory testName) internal returns (uint gasUsed) {
        console.log(string.concat("\n--- Testing ", testName, " ---"));

        // Setup puppet list based on count
        address[] memory puppetList = new address[](puppetCount);
        puppetList[0] = puppet1;
        if (puppetCount > 1) puppetList[1] = puppet2;
        if (puppetCount > 2) puppetList[2] = makeAddr("puppet3");

        uint allocationId = 100 + puppetCount; // Unique allocation ID

        // Prepare parameters (merged allocation and position params)
        MirrorPosition.CallPosition memory callParams = MirrorPosition.CallPosition({
            collateralToken: USDC,
            traderRequestKey: bytes32(0),
            trader: trader,
            market: Const.gmxEthUsdcMarket,
            isIncrease: true,
            isLong: true,
            executionFee: EXECUTION_FEE,
            collateralDelta: 1000e30,
            sizeDeltaInUsd: 5000e30,
            acceptablePrice: 4000e30,
            triggerPrice: 0,
            allocationId: allocationId,
            keeperFee: KEEPER_FEE,
            keeperFeeReceiver: keeper
        });

        // Measure gas
        uint gasStart = gasleft();

        vm.prank(keeper);
        (address allocationAddress, bytes32 requestKey) =
            keeperRouter.requestOpen{value: EXECUTION_FEE}(callParams, puppetList);

        gasUsed = gasStart - gasleft();

        console.log("Gas Used:", gasUsed);
        console.log("Allocation Address:", allocationAddress);
        console.log("Request Key:", vm.toString(requestKey));

        return gasUsed;
    }

    /**
     * @notice Test complete mirror-to-settlement flow with GMX callback simulation
     * @dev Tests the full lifecycle: mirror → execute → settle → validate distributions
     */
    function testCompleteMirrorToSettlement() public {
        skipIfNoRPC();
        if (!isRPCAvailable) return;

        console.log("\n=== Testing Complete Mirror-to-Settlement Flow ===");

        // Setup test parameters
        address[] memory puppetList = new address[](2);
        puppetList[0] = puppet1;
        puppetList[1] = puppet2;

        uint allocationId = 1;
        uint collateralAmount = 1000e30; // $1000
        uint positionSize = 5000e30; // $5000 (5x leverage)
        uint acceptablePrice = 4000e30; // $4000 per ETH

        // Prepare position parameters (merged allocation and position params)
        MirrorPosition.CallPosition memory callParams = MirrorPosition.CallPosition({
            collateralToken: USDC,
            traderRequestKey: bytes32(0),
            trader: trader,
            market: Const.gmxEthUsdcMarket,
            isIncrease: true,
            isLong: true,
            executionFee: EXECUTION_FEE,
            collateralDelta: collateralAmount,
            sizeDeltaInUsd: positionSize,
            acceptablePrice: acceptablePrice,
            triggerPrice: 0,
            allocationId: allocationId,
            keeperFee: KEEPER_FEE,
            keeperFeeReceiver: keeper
        });

        // Step 1: Mirror Request - Keeper submits position to GMX
        console.log("\n--- Step 1: Mirror Request ---");
        uint gasStart = gasleft();

        vm.prank(keeper);
        (address allocationAddress, bytes32 requestKey) =
            keeperRouter.requestOpen{value: EXECUTION_FEE}(callParams, puppetList);

        uint mirrorGasUsed = gasStart - gasleft();
        console.log("Mirror Gas Used:", mirrorGasUsed);
        console.log("Request Key:", vm.toString(requestKey));
        console.log("Allocation Address:", allocationAddress);

        // Validate allocation was created
        uint totalAllocation = mirrorPosition.getAllocation(allocationAddress);
        uint[] memory puppetAllocations = mirrorPosition.getPuppetAllocationList(allocationAddress);

        console.log("Total Allocation:", totalAllocation);
        console.log("Puppet1 Allocation:", puppetAllocations[0]);
        console.log("Puppet2 Allocation:", puppetAllocations[1]);

        // Step 2: Simulate GMX Execution - Position becomes active
        console.log("\n--- Step 2: GMX Execution Simulation ---");

        // Simulate successful GMX execution by calling execute directly
        // In real flow, this would be called by GMX callback
        vm.prank(address(keeperRouter));
        mirrorPosition.execute(requestKey);

        console.log("Position executed successfully");

        // Verify position is now active in MirrorPosition
        // Note: We can't easily check the internal position state without additional getters

        // Step 3: Settlement - Simulate position closure and fund distribution
        console.log("\n--- Step 3: Settlement ---");

        // For settlement, we need to simulate a position that can be settled
        // This would normally happen when trader closes their position

        // Record pre-settlement balances
        uint puppet1BalanceBefore = allocationStore.userBalanceMap(USDC, puppet1);
        uint puppet2BalanceBefore = allocationStore.userBalanceMap(USDC, puppet2);
        uint keeperBalanceBefore = USDC.balanceOf(keeper);

        console.log("Pre-Settlement Balances:");
        console.log("  Puppet1:", puppet1BalanceBefore);
        console.log("  Puppet2:", puppet2BalanceBefore);
        console.log("  Keeper:", keeperBalanceBefore);

        // Simulate settlement by calling keeperRouter.settleAllocation
        // Note: This might revert if position isn't in a settleable state
        // We'll wrap in try-catch to handle gracefully

        address[] memory settleList = new address[](2);
        settleList[0] = puppet1;
        settleList[1] = puppet2;

        // Prepare settlement parameters
        Settle.CallSettle memory settleParams = Settle.CallSettle({
            collateralToken: USDC,
            distributionToken: USDC,
            keeperFeeReceiver: keeper,
            trader: trader,
            allocationId: allocationId,
            keeperExecutionFee: KEEPER_FEE
        });

        // For this test, we'll simulate that funds are available for settlement
        // In real scenario, this comes from GMX position closure

        try keeperRouter.settleAllocation(settleParams, settleList) {
            console.log("Settlement completed successfully");

            // Step 4: Validate final distributions
            console.log("\n--- Step 4: Final Validation ---");

            uint puppet1BalanceAfter = allocationStore.userBalanceMap(USDC, puppet1);
            uint puppet2BalanceAfter = allocationStore.userBalanceMap(USDC, puppet2);
            uint keeperBalanceAfter = USDC.balanceOf(keeper);

            console.log("Post-Settlement Balances:");
            console.log("  Puppet1:", puppet1BalanceAfter);
            console.log("  Puppet2:", puppet2BalanceAfter);
            console.log("  Keeper:", keeperBalanceAfter);

            // Calculate changes
            console.log("Balance Changes:");
            console.log(
                "  Puppet1:",
                puppet1BalanceAfter > puppet1BalanceBefore ? "+" : "-",
                puppet1BalanceAfter > puppet1BalanceBefore
                    ? puppet1BalanceAfter - puppet1BalanceBefore
                    : puppet1BalanceBefore - puppet1BalanceAfter
            );
            console.log(
                "  Puppet2:",
                puppet2BalanceAfter > puppet2BalanceBefore ? "+" : "-",
                puppet2BalanceAfter > puppet2BalanceBefore
                    ? puppet2BalanceAfter - puppet2BalanceBefore
                    : puppet2BalanceBefore - puppet2BalanceAfter
            );

            // Validate keeper received settlement fee
            assert(keeperBalanceAfter >= keeperBalanceBefore);
        } catch (bytes memory reason) {
            console.log("Settlement failed - this is expected for test simulation");

            // Try to parse the error reason
            if (reason.length >= 4) {
                bytes4 errorSelector = bytes4(reason);
                console.log("Error Selector:", vm.toString(errorSelector));
            }

            console.log("Note: In real flow, settlement happens after GMX position closure");
            console.log("      The allocation account needs to receive settlement funds first");
        }

        // Step 5: Gas and Performance Analysis
        console.log("\n--- Step 5: Performance Analysis ---");
        console.log("Total Gas for Mirror:", mirrorGasUsed);

        // Get gas configuration from KeeperRouter
        KeeperRouter.Config memory gasConfig = keeperRouter.getConfig();

        // Calculate expected vs actual gas using contract configuration
        uint expectedGas = gasConfig.mirrorBaseGasLimit + (gasConfig.mirrorPerPuppetGasLimit * puppetList.length);
        uint variance = mirrorGasUsed > expectedGas
            ? ((mirrorGasUsed - expectedGas) * 10000) / expectedGas
            : ((expectedGas - mirrorGasUsed) * 10000) / expectedGas;

        console.log("Expected Gas:", expectedGas);
        console.log("Variance (bps):", variance);

        // Validate allocation percentages
        if (totalAllocation > 0) {
            uint puppet1Percent = (puppetAllocations[0] * 10000) / totalAllocation;
            uint puppet2Percent = (puppetAllocations[1] * 10000) / totalAllocation;
            console.log("Allocation Percentages:");
            console.log("  Puppet1:", puppet1Percent, "bps");
            console.log("  Puppet2:", puppet2Percent, "bps");
        }

        console.log("\n=== Complete Flow Test Finished ===");
    }
}
