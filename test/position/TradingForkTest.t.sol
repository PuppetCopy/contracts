// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

// import {DataStore, Oracle, Price} from "@gmx/contracts/oracle/Oracle.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Test} from "forge-std/src/Test.sol";
import {console} from "forge-std/src/console.sol";

import {GmxExecutionCallback} from "src/position/GmxExecutionCallback.sol";
import {MatchingRule} from "src/position/MatchingRule.sol";
import {MirrorPosition} from "src/position/MirrorPosition.sol";
import {IGmxExchangeRouter} from "src/position/interface/IGmxExchangeRouter.sol";
import {AllocationStore} from "src/shared/AllocationStore.sol";
import {Dictatorship} from "src/shared/Dictatorship.sol";
import {FeeMarketplace} from "src/shared/FeeMarketplace.sol";
import {FeeMarketplaceStore} from "src/shared/FeeMarketplaceStore.sol";
import {TokenRouter} from "src/shared/TokenRouter.sol";
import {PuppetToken} from "src/tokenomics/PuppetToken.sol";
import {BankStore} from "src/utils/BankStore.sol";
import {Error} from "src/utils/Error.sol";

import {Const} from "script/Const.sol";

interface IChainlinkPriceFeedProvider {
    struct ValidatedPrice {
        address token;
        uint min;
        uint max;
        uint timestamp;
        address provider;
    }

    /// @notice Gets the oracle price for a given token using Chainlink price feeds
    /// @dev The timestamp returned is based on the current blockchain timestamp
    /// @param token The token address to get the price for
    /// @param data Additional data (unused in this implementation)
    /// @return The validated price with min/max prices, timestamp, and provider address
    function getOraclePrice(address token, bytes memory data) external view returns (ValidatedPrice memory);
}

contract TradingForkTest is Test {
    // Real Arbitrum addresses
    IERC20 constant USDC = IERC20(Const.usdc);
    IERC20 constant WETH = IERC20(Const.wnt);

    // Test contracts
    Dictatorship dictator;
    TokenRouter tokenRouter;
    PuppetToken puppetToken;
    AllocationStore allocationStore;
    MatchingRule matchingRule;
    GmxExecutionCallback gmxExecutionCallback;
    FeeMarketplace feeMarketplace;
    FeeMarketplaceStore feeMarketplaceStore;
    MirrorPosition mirrorPosition;

    // Test users
    address owner = makeAddr("owner");
    address trader = makeAddr("trader");
    address puppet1 = makeAddr("puppet1");
    address puppet2 = makeAddr("puppet2");

    function setUp() public {
        vm.createFork(vm.envString("RPC_URL"));
        vm.rollFork(340881246);

        vm.startPrank(owner);

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
                burnBasisPoints: 10000, // 100% burn
                feeDistributor: BankStore(address(0))
            })
        );
        allocationStore = new AllocationStore(dictator, tokenRouter);
        matchingRule = new MatchingRule(
            dictator,
            allocationStore,
            MatchingRule.Config({
                minExpiryDuration: 1 days,
                minAllowanceRate: 100, // 1%
                maxAllowanceRate: 10000, // 100%
                minActivityThrottle: 1 hours,
                maxActivityThrottle: 30 days
            })
        );
        gmxExecutionCallback = new GmxExecutionCallback(
            dictator, GmxExecutionCallback.Config({mirrorPosition: MirrorPosition(_getNextContractAddress(msg.sender))})
        );
        mirrorPosition = new MirrorPosition(
            dictator,
            allocationStore,
            MirrorPosition.Config({
                gmxExchangeRouter: IGmxExchangeRouter(Const.gmxExchangeRouter),
                callbackHandler: address(gmxExecutionCallback),
                gmxOrderVault: Const.gmxOrderVault,
                referralCode: bytes32("PUPPET"),
                increaseCallbackGasLimit: 2_000_000,
                decreaseCallbackGasLimit: 2_000_000,
                platformSettleFeeFactor: 0.1e30, // 10%
                maxPuppetList: 50,
                maxKeeperFeeToAllocationRatio: 0.1e30, // 10%
                maxKeeperFeeToAdjustmentRatio: 0.1e30, // 5%
                maxKeeperFeeToCollectDustRatio: 0.1e30 // 10%
            })
        );

        // Set up permissions
        dictator.setPermission(tokenRouter, tokenRouter.transfer.selector, address(allocationStore));
        dictator.setPermission(tokenRouter, tokenRouter.transfer.selector, address(feeMarketplaceStore));
        dictator.setAccess(allocationStore, address(matchingRule));
        dictator.setAccess(allocationStore, address(mirrorPosition));
        dictator.setAccess(allocationStore, address(feeMarketplace));
        dictator.setAccess(feeMarketplaceStore, address(feeMarketplace));

        dictator.setPermission(mirrorPosition, mirrorPosition.requestMirror.selector, owner);
        dictator.setPermission(mirrorPosition, mirrorPosition.requestAdjust.selector, owner);
        dictator.setPermission(mirrorPosition, mirrorPosition.settle.selector, owner);
        dictator.setPermission(mirrorPosition, mirrorPosition.execute.selector, owner);
        dictator.setPermission(mirrorPosition, mirrorPosition.setTokenDustThresholdList.selector, owner);
        dictator.setPermission(
            mirrorPosition, mirrorPosition.initializeTraderActivityThrottle.selector, address(matchingRule)
        );

        dictator.setPermission(matchingRule, matchingRule.setRule.selector, owner);
        dictator.setPermission(matchingRule, matchingRule.deposit.selector, owner);
        dictator.setPermission(matchingRule, matchingRule.setTokenAllowanceList.selector, owner);
        dictator.initContract(matchingRule);

        dictator.setPermission(feeMarketplace, feeMarketplace.deposit.selector, address(mirrorPosition));
        dictator.setPermission(feeMarketplace, feeMarketplace.setAskPrice.selector, owner);

        // Set allowed tokens
        IERC20[] memory allowedTokens = new IERC20[](2);
        allowedTokens[0] = USDC;
        allowedTokens[1] = WETH;

        uint[] memory allowanceCaps = new uint[](2);
        allowanceCaps[0] = 1000e6; // 1000 USDC
        allowanceCaps[1] = 1e18; // 1 ETH

        matchingRule.setTokenAllowanceList(allowedTokens, allowanceCaps);

        // Initialize FeeMarketplace
        dictator.initContract(feeMarketplace);

        // Set ask price for USDC
        feeMarketplace.setAskPrice(USDC, 100e18);

        // Initialize MirrorPosition
        dictator.initContract(mirrorPosition);

        // Set dust thresholds
        uint[] memory dustThresholds = new uint[](2);
        dustThresholds[0] = 1e6; // 1 USDC
        dustThresholds[1] = 0.001e18; // 0.001 ETH

        mirrorPosition.setTokenDustThresholdList(allowedTokens, dustThresholds);
        // Fund test accounts with real tokens
        vm.deal(owner, 100 ether);

        deal(address(WETH), owner, 100 ether);
        WETH.approve(address(tokenRouter), type(uint).max);
        matchingRule.deposit(WETH, owner, puppet1, 0.1 ether);
        matchingRule.deposit(WETH, owner, puppet2, 0.1 ether);

        deal(address(USDC), owner, 10000e6);
        USDC.approve(address(tokenRouter), type(uint).max);
        matchingRule.deposit(USDC, owner, puppet1, 100e6);
        matchingRule.deposit(USDC, owner, puppet2, 100e6);
        vm.stopPrank();
    }

    function testForkOpenPosition() public {
        vm.startPrank(owner);

        // Create puppet list
        address[] memory puppetList = new address[](2);
        puppetList[0] = puppet1;
        puppetList[1] = puppet2;

        // Set up matching rules for puppets
        matchingRule.setRule(
            mirrorPosition,
            USDC,
            puppet1,
            trader,
            MatchingRule.Rule({
                allowanceRate: 1000, // 10%
                throttleActivity: 1 hours,
                expiry: block.timestamp + 30 days
            })
        );

        matchingRule.setRule(
            mirrorPosition,
            USDC,
            puppet2,
            trader,
            MatchingRule.Rule({
                allowanceRate: 1500, // 15%
                throttleActivity: 1 hours,
                expiry: block.timestamp + 30 days
            })
        );

        // Encode and execute the call
        IChainlinkPriceFeedProvider.ValidatedPrice memory price =
            IChainlinkPriceFeedProvider(Const.chainlinkPriceFeedProvider).getOraclePrice(Const.wnt, "");

        // Create position call parameters
        MirrorPosition.CallPosition memory callParams = MirrorPosition.CallPosition({
            collateralToken: USDC,
            trader: trader,
            market: Const.gmxEthUsdcMarket, // ETH/USD market
            keeperExecutionFeeReceiver: owner,
            isIncrease: true,
            isLong: true,
            executionFee: 0.001 ether, // GMX execution fee
            collateralDelta: 100e6, // 100 USDC
            sizeDeltaInUsd: 1000e30, // 1000 USD position (10x leverage)
            acceptablePrice: price.min * 110, // 10% slippage
            triggerPrice: price.min,
            keeperExecutionFee: 1e6 // 1 USDC keeper fee
        });

        // Check initial balances
        uint puppet1BalanceBefore = allocationStore.userBalanceMap(USDC, puppet1);
        uint puppet2BalanceBefore = allocationStore.userBalanceMap(USDC, puppet2);

        console.log("Puppet1 balance before:", puppet1BalanceBefore);
        console.log("Puppet2 balance before:", puppet2BalanceBefore);

        // Request mirror position
        (address allocationAddress, uint allocationId, bytes32 requestKey) =
            mirrorPosition.requestMirror{value: callParams.executionFee}(matchingRule, callParams, puppetList);

        console.log("Allocation address:", allocationAddress);
        console.log("Allocation ID:", allocationId);
        console.log("Request key:", vm.toString(requestKey));

        // Check allocations
        uint puppet1Allocation = mirrorPosition.allocationPuppetMap(allocationAddress, puppet1);
        uint puppet2Allocation = mirrorPosition.allocationPuppetMap(allocationAddress, puppet2);
        uint totalAllocation = mirrorPosition.getAllocation(allocationAddress);

        console.log("Puppet1 allocation:", puppet1Allocation);
        console.log("Puppet2 allocation:", puppet2Allocation);
        console.log("Total net allocation:", totalAllocation);

        // Verify allocations are correct
        assertGt(puppet1Allocation, 0, "Puppet1 should have allocation");
        assertGt(puppet2Allocation, 0, "Puppet2 should have allocation");
        assertEq(
            totalAllocation,
            puppet1Allocation + puppet2Allocation - callParams.keeperExecutionFee,
            "Net allocation should be gross minus keeper fee"
        );

        // Check balances were deducted
        uint puppet1BalanceAfter = allocationStore.userBalanceMap(USDC, puppet1);
        uint puppet2BalanceAfter = allocationStore.userBalanceMap(USDC, puppet2);

        assertEq(puppet1BalanceAfter, puppet1BalanceBefore - puppet1Allocation, "Puppet1 balance should be reduced");
        assertEq(puppet2BalanceAfter, puppet2BalanceBefore - puppet2Allocation, "Puppet2 balance should be reduced");

        // Execute the position (simulate GMX callback)
        mirrorPosition.execute(requestKey);

        // Check position was created
        MirrorPosition.Position memory position = mirrorPosition.getPosition(allocationAddress);
        assertEq(position.traderSize, callParams.sizeDeltaInUsd, "Trader size should match");
        assertEq(position.traderCollateral, callParams.collateralDelta, "Trader collateral should match");
        assertGt(position.size, 0, "Mirror position size should be > 0");

        console.log("Position created successfully!");
        console.log("Trader size:", position.traderSize);
        console.log("Trader collateral:", position.traderCollateral);
        console.log("Mirror size:", position.size);

        vm.stopPrank();
    }

    // function testForkDecreasePosition() public {
    //     vm.startPrank(owner);

    //     // Create puppet list
    //     address[] memory puppetList = new address[](2);
    //     puppetList[0] = puppet1;
    //     puppetList[1] = puppet2;

    //     // Set up matching rules for puppets
    //     matchingRule.setRule(
    //         mirrorPosition,
    //         USDC,
    //         puppet1,
    //         trader,
    //         MatchingRule.Rule({
    //             allowanceRate: 1000, // 10%
    //             throttleActivity: 1 hours,
    //             expiry: block.timestamp + 30 days
    //         })
    //     );

    //     matchingRule.setRule(
    //         mirrorPosition,
    //         USDC,
    //         puppet2,
    //         trader,
    //         MatchingRule.Rule({
    //             allowanceRate: 1500, // 15%
    //             throttleActivity: 1 hours,
    //             expiry: block.timestamp + 30 days
    //         })
    //     );

    //     // Get current price for calculations
    //     IChainlinkPriceFeedProvider.ValidatedPrice memory price =
    //         IChainlinkPriceFeedProvider(Const.chainlinkPriceFeedProvider).getOraclePrice(Const.wnt, "");

    //     // STEP 1: Create initial position (increase)
    //     MirrorPosition.CallPosition memory increaseParams = MirrorPosition.CallPosition({
    //         collateralToken: USDC,
    //         trader: trader,
    //         market: Const.gmxEthUsdcMarket,
    //         keeperExecutionFeeReceiver: owner,
    //         isIncrease: true,
    //         isLong: true,
    //         executionFee: 0.001 ether,
    //         collateralDelta: 100e6, // 100 USDC
    //         sizeDeltaInUsd: 1000e30, // 1000 USD position (10x leverage)
    //         acceptablePrice: price.min * 110, // 10% slippage
    //         triggerPrice: price.min,
    //         keeperExecutionFee: 1e6 // 1 USDC keeper fee
    //     });

    //     // Request initial mirror position
    //     (address allocationAddress, uint allocationId, bytes32 requestKey) =
    //         mirrorPosition.requestMirror{value: increaseParams.executionFee}(matchingRule, increaseParams,
    // puppetList);

    //     // Execute the initial position
    //     mirrorPosition.execute(requestKey);

    //     // Verify position was created
    //     MirrorPosition.Position memory position = mirrorPosition.getPosition(allocationAddress);
    //     assertGt(position.size, 0, "Initial position size should be > 0");
    //     assertEq(position.traderSize, increaseParams.sizeDeltaInUsd, "Initial trader size should match");

    //     console.log("Initial position created:");
    //     console.log("- Trader size:", position.traderSize);
    //     console.log("- Mirror size:", position.size);
    //     console.log("- Trader collateral:", position.traderCollateral);

    //     // STEP 2: Decrease the position
    //     MirrorPosition.CallPosition memory decreaseParams = MirrorPosition.CallPosition({
    //         collateralToken: USDC,
    //         trader: trader,
    //         market: Const.gmxEthUsdcMarket,
    //         keeperExecutionFeeReceiver: owner,
    //         isIncrease: false, // This is a decrease
    //         isLong: true,
    //         executionFee: 0.001 ether,
    //         collateralDelta: 50e6, // Reduce collateral by 50 USDC
    //         sizeDeltaInUsd: 500e30, // Reduce size by 500 USD (half the position)
    //         acceptablePrice: price.min * 90, // 10% slippage for decrease
    //         triggerPrice: price.min,
    //         keeperExecutionFee: 1e6 // 1 USDC keeper fee
    //     });

    //     // Check puppet balances before decrease
    //     uint puppet1BalanceBefore = allocationStore.userBalanceMap(USDC, puppet1);
    //     uint puppet2BalanceBefore = allocationStore.userBalanceMap(USDC, puppet2);

    //     console.log("Balances before decrease:");
    //     console.log("- Puppet1:", puppet1BalanceBefore);
    //     console.log("- Puppet2:", puppet2BalanceBefore);

    //     // Request position adjustment (decrease)
    //     bytes32 decreaseRequestKey =
    //         mirrorPosition.requestAdjust{value: decreaseParams.executionFee}(decreaseParams, puppetList,
    // allocationId);

    //     console.log("Decrease request key:", vm.toString(decreaseRequestKey));

    //     // Verify request adjustment was stored
    //     MirrorPosition.RequestAdjustment memory adjustmentRequest =
    //         mirrorPosition.getRequestAdjustment(decreaseRequestKey);
    //     assertEq(adjustmentRequest.allocationAddress, allocationAddress, "Allocation address should match");
    //     assertFalse(adjustmentRequest.traderIsIncrease, "Should be decrease");
    //     assertEq(adjustmentRequest.traderSizeDelta, decreaseParams.sizeDeltaInUsd, "Size delta should match");
    //     assertEq(
    //         adjustmentRequest.traderCollateralDelta, decreaseParams.collateralDelta, "Collateral delta should match"
    //     );

    //     // Execute the decrease
    //     mirrorPosition.execute(decreaseRequestKey);

    //     // Verify position was decreased
    //     MirrorPosition.Position memory updatedPosition = mirrorPosition.getPosition(allocationAddress);

    //     uint expectedTraderSize = position.traderSize - decreaseParams.sizeDeltaInUsd;
    //     uint expectedTraderCollateral = position.traderCollateral - decreaseParams.collateralDelta;

    //     assertEq(updatedPosition.traderSize, expectedTraderSize, "Trader size should be reduced");
    //     assertEq(updatedPosition.traderCollateral, expectedTraderCollateral, "Trader collateral should be reduced");
    //     assertLt(updatedPosition.size, position.size, "Mirror position size should be reduced");
    //     assertGt(updatedPosition.size, 0, "Position should still exist after partial decrease");

    //     console.log("Position after decrease:");
    //     console.log("- Trader size:", updatedPosition.traderSize);
    //     console.log("- Mirror size:", updatedPosition.size);
    //     console.log("- Trader collateral:", updatedPosition.traderCollateral);

    //     // Calculate expected new leverage
    //     uint newTraderLeverage = (updatedPosition.traderCollateral > 0)
    //         ? (updatedPosition.traderSize * 10000) / updatedPosition.traderCollateral
    //         : 0;

    //     console.log("New trader leverage (basis points):", newTraderLeverage);

    //     // Verify the decrease was proportional
    //     assertApproxEqRel(
    //         updatedPosition.size * 2, // Doubled because we reduced by half
    //         position.size,
    //         0.01e18, // 1% tolerance for rounding
    //         "Position size should be approximately halved"
    //     );

    //     // Check that puppet balances were adjusted for keeper fees
    //     uint puppet1BalanceAfter = allocationStore.userBalanceMap(USDC, puppet1);
    //     uint puppet2BalanceAfter = allocationStore.userBalanceMap(USDC, puppet2);

    //     console.log("Balances after decrease:");
    //     console.log("- Puppet1:", puppet1BalanceAfter);
    //     console.log("- Puppet2:", puppet2BalanceAfter);

    //     // Balances should be reduced due to keeper fees during adjustment
    //     assertLe(puppet1BalanceAfter, puppet1BalanceBefore, "Puppet1 balance should be reduced or same");
    //     assertLe(puppet2BalanceAfter, puppet2BalanceBefore, "Puppet2 balance should be reduced or same");

    //     console.log("Position decrease test completed successfully!");

    //     vm.stopPrank();
    // }

    function testKeeperFeeExceedsCostFactor() public {
        vm.startPrank(owner);

        // Create puppet list
        address[] memory puppetList = new address[](1);
        puppetList[0] = puppet1;

        // Set up matching rule with a small allowance rate
        matchingRule.setRule(
            mirrorPosition,
            USDC,
            puppet1,
            trader,
            MatchingRule.Rule({
                allowanceRate: 400, // Only 3% allowance rate (very small)
                throttleActivity: 1 hours,
                expiry: block.timestamp + 30 days
            })
        );

        // Get current price
        IChainlinkPriceFeedProvider.ValidatedPrice memory price =
            IChainlinkPriceFeedProvider(Const.chainlinkPriceFeedProvider).getOraclePrice(Const.wnt, "");

        // Create position with a very high keeper fee relative to allocation
        MirrorPosition.CallPosition memory callParams = MirrorPosition.CallPosition({
            collateralToken: USDC,
            trader: trader,
            market: Const.gmxEthUsdcMarket,
            keeperExecutionFeeReceiver: owner,
            isIncrease: true,
            isLong: true,
            executionFee: 0.001 ether,
            collateralDelta: 100e6,
            sizeDeltaInUsd: 1000e30,
            acceptablePrice: price.min * 110,
            triggerPrice: price.min,
            keeperExecutionFee: 301831 // Very high keeper fee (50 USDC when puppet only has 1% of 100 USDC = 1 USDC
                // allocated)
        });

        mirrorPosition.requestMirror{value: callParams.executionFee}(matchingRule, callParams, puppetList);

        vm.stopPrank();
    }

    function _getNextContractAddress(
        address user
    ) internal view returns (address) {
        return vm.computeCreateAddress(user, vm.getNonce(user) + 1);
    }

    function _getNextContractAddress(address user, uint count) internal view returns (address) {
        return vm.computeCreateAddress(user, vm.getNonce(user) + count);
    }
}
