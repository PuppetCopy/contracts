// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {console} from "forge-std/src/console.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {MatchRule} from "src/position/MatchRule.sol";
import {MirrorPosition} from "src/position/MirrorPosition.sol";
import {IGmxExchangeRouter} from "src/position/interface/IGmxExchangeRouter.sol";
import {IGmxOracle} from "src/position/interface/IGmxOracle.sol";
import {GmxPositionUtils} from "src/position/utils/GmxPositionUtils.sol";
import {PositionUtils} from "src/position/utils/PositionUtils.sol";
import {Error} from "src/shared/Error.sol";
import {Subaccount} from "src/shared/Subaccount.sol";
import {SubaccountStore} from "src/shared/SubaccountStore.sol";
import {FeeMarketplace} from "src/tokenomics/FeeMarketplace.sol";
import {FeeMarketplaceStore} from "src/tokenomics/FeeMarketplaceStore.sol";
import {BankStore} from "src/utils/BankStore.sol";
import {Precision} from "src/utils/Precision.sol";

import {BasicSetup} from "../base/BasicSetup.t.sol";
import {MockGmxExchangeRouter} from "../mock/MockGmxExchangeRouter.sol";
import {Address} from "script/Const.sol";

import {MockERC20} from "test/mock/MockERC20.sol";

// TODO: Add tests for the Trading contract
// MirrorPosition__NoAllocation - Increase request without allocation
// MirrorPosition__PendingAllocationExecution - Cannot allow additional requests during pending initial allocation
// MirrorPosition__PendingAllocation - Trying to allocate when there's already a pending allocation
// MirrorPosition__PuppetListLimit - Exceed the maximum allowed puppet list length
// MirrorPosition__NoPuppetAllocation - nothing has been allocated while processing puppet list
// MirrorPosition__ExecutionRequestMissing - Trying to process a request that doesn't exist
// MirrorPosition__PositionDoesNotExist - Trying to decrease a non-existent position
// MirrorPosition__NoSettledFunds - Trying to settle an allocation that has no funds
// MirrorPosition__InvalidPuppetListIntegrity - Settlement puppet list doesn't match allocation's list
// TODO: Test edge cases for allocation distribution calculation
// TODO: Test gas fee tracking and accounting
// TODO: Test partial decrease vs full decrease position differences
// TODO: Test performance contribution fees to the fee marketplace
// TODO: Test throttling mechanism between puppets and traders
// TODO: Test allocation expiry handling

contract TradingTest is BasicSetup {
    SubaccountStore subaccountStore;
    MatchRule matchRule;
    FeeMarketplace feeMarketplace;
    MirrorPosition mirrorPosition;
    MockGmxExchangeRouter mockGmxExchangeRouter;
    FeeMarketplaceStore feeMarketplaceStore;

    IGmxOracle gmxOracle = IGmxOracle(Address.gmxOracle);

    function setUp() public override {
        super.setUp();

        mockGmxExchangeRouter = new MockGmxExchangeRouter();

        // Deploy core contracts
        subaccountStore = new SubaccountStore(dictator, tokenRouter);
        matchRule = new MatchRule(dictator, subaccountStore);

        feeMarketplaceStore = new FeeMarketplaceStore(dictator, tokenRouter, puppetToken);
        feeMarketplace = new FeeMarketplace(dictator, tokenRouter, feeMarketplaceStore, puppetToken);

        mirrorPosition = new MirrorPosition(dictator, subaccountStore, matchRule, feeMarketplace);

        // Config
        IERC20[] memory tokenAllowanceCapList = new IERC20[](2);
        tokenAllowanceCapList[0] = wnt;
        tokenAllowanceCapList[1] = usdc;
        uint[] memory tokenAllowanceCapAmountList = new uint[](2);
        tokenAllowanceCapAmountList[0] = 0.2e18;
        tokenAllowanceCapAmountList[1] = 500e30;

        // Configure contracts
        dictator.initContract(
            matchRule,
            abi.encode(
                MatchRule.Config({
                    minExpiryDuration: 1 days,
                    minAllowanceRate: 100, // 10 basis points
                    maxAllowanceRate: 10000,
                    minActivityThrottle: 1 hours,
                    maxActivityThrottle: 30 days,
                    tokenAllowanceList: tokenAllowanceCapList,
                    tokenAllowanceAmountList: tokenAllowanceCapAmountList
                })
            )
        );

        dictator.initContract(
            feeMarketplace,
            abi.encode(
                FeeMarketplace.Config({
                    distributionTimeframe: 1 days,
                    burnBasisPoints: 10000,
                    feeDistributor: BankStore(address(0))
                })
            )
        );

        dictator.initContract(
            mirrorPosition,
            abi.encode(
                MirrorPosition.Config({
                    gmxExchangeRouter: mockGmxExchangeRouter,
                    callbackHandler: address(mirrorPosition),
                    gmxOrderVault: Address.gmxOrderVault,
                    referralCode: Address.referralCode,
                    increaseCallbackGasLimit: 2_000_000,
                    decreaseCallbackGasLimit: 2_000_000,
                    limitAllocationListLength: 100,
                    performanceFee: 0.1e30,
                    traderPerformanceFee: 0
                })
            )
        );

        dictator.setPermission(tokenRouter, tokenRouter.transfer.selector, address(subaccountStore));
        dictator.setAccess(subaccountStore, address(matchRule));
        dictator.setAccess(subaccountStore, address(mirrorPosition));
        dictator.setAccess(subaccountStore, address(feeMarketplace));

        // Set permissions
        dictator.setPermission(mirrorPosition, mirrorPosition.allocate.selector, users.owner);
        dictator.setPermission(mirrorPosition, mirrorPosition.mirror.selector, users.owner);
        dictator.setPermission(mirrorPosition, mirrorPosition.settle.selector, users.owner);
        dictator.setPermission(mirrorPosition, mirrorPosition.increase.selector, users.owner);
        dictator.setPermission(mirrorPosition, mirrorPosition.decrease.selector, users.owner);

        dictator.setPermission(feeMarketplace, feeMarketplace.deposit.selector, address(mirrorPosition));
        dictator.setPermission(feeMarketplace, feeMarketplace.acceptOffer.selector, users.owner);
        dictator.setPermission(feeMarketplace, feeMarketplace.setAskPrice.selector, users.owner);
        dictator.setAccess(feeMarketplaceStore, address(feeMarketplace));
        dictator.setAccess(subaccountStore, address(feeMarketplaceStore));
        dictator.setPermission(tokenRouter, tokenRouter.transfer.selector, address(feeMarketplaceStore));
        feeMarketplace.setAskPrice(usdc, 100e18);

        // Ensure owner has permissions to act on behalf of users
        dictator.setPermission(matchRule, matchRule.setRule.selector, users.owner);
        dictator.setPermission(matchRule, matchRule.deposit.selector, users.owner);

        // Pre-approve token allowances for users
        vm.startPrank(users.alice);
        usdc.approve(address(subaccountStore), type(uint).max);
        wnt.approve(address(subaccountStore), type(uint).max);

        vm.startPrank(users.bob);
        usdc.approve(address(subaccountStore), type(uint).max);
        wnt.approve(address(subaccountStore), type(uint).max);

        vm.startPrank(users.owner);
    }

    function simpleE2eExecution() public {
        address trader = users.bob;

        uint estimatedGasLimit = 5_000_000;
        uint executionFee = tx.gasprice * estimatedGasLimit;

        address[] memory puppetList = generatePuppetList(usdc, trader, 10);

        bytes32 mockSourceRequestKey = keccak256(abi.encodePacked(users.bob, uint(0)));
        bytes32 matchKey = PositionUtils.getMatchKey(usdc, trader);
        bytes32 positionKey = keccak256(abi.encodePacked("position-1"));

        bytes32 allocationKey =
            mirrorPosition.allocate(usdc, mockSourceRequestKey, matchKey, positionKey, trader, puppetList);

        bytes32 increaseRequestKey = mirrorPosition.mirror{value: executionFee}(
            MirrorPosition.MirrorPositionParams({
                trader: trader,
                market: Address.gmxEthUsdcMarket,
                collateralToken: usdc,
                allocationKey: allocationKey,
                sourceRequestKey: mockSourceRequestKey,
                isIncrease: true,
                isLong: true,
                executionFee: executionFee,
                collateralDelta: 120e6,
                sizeDeltaInUsd: 30e30,
                acceptablePrice: 1000e12,
                triggerPrice: 1000e12
            })
        );

        // Simulate position increase callback
        mirrorPosition.increase(increaseRequestKey);

        // Now simulate decrease position
        bytes32 decreaseRequestKey = mirrorPosition.mirror{value: executionFee}(
            MirrorPosition.MirrorPositionParams({
                trader: trader,
                market: Address.gmxEthUsdcMarket,
                collateralToken: usdc,
                allocationKey: allocationKey,
                sourceRequestKey: mockSourceRequestKey,
                isIncrease: false,
                isLong: true,
                executionFee: executionFee,
                collateralDelta: 120e6,
                sizeDeltaInUsd: 30e30,
                acceptablePrice: 1000e12,
                triggerPrice: 1000e12
            })
        );

        // Need to simulate some tokens coming back to the contract
        // In real environment, GMX would send funds back
        // usdc.balanceOf(address(subaccountStore));
        deal(address(usdc), address(subaccountStore), usdc.balanceOf(address(subaccountStore)) + 11e6 * 10);
        // Return more than collateral to simulate profit
        // usdc.balanceOf(address(subaccountStore));

        // Simulate position decrease callback
        mirrorPosition.decrease(decreaseRequestKey);

        // log allocation
        mirrorPosition.allocationMap(allocationKey);

        // Settle the allocation
        mirrorPosition.settle(allocationKey, puppetList);
    }

    function generatePuppetList(
        MockERC20 collateralToken,
        address trader,
        uint _length
    ) internal returns (address[] memory) {
        address[] memory puppetList = new address[](_length);
        for (uint i; i < _length; i++) {
            puppetList[i] =
                createPuppet(collateralToken, trader, string(abi.encodePacked("puppet:", Strings.toString(i))), 100e6);
        }
        return puppetList;
    }

    function createPuppet(
        MockERC20 collateralToken,
        address trader,
        string memory name,
        uint fundValue
    ) internal returns (address payable) {
        address payable user = payable(makeAddr(name));
        // _dealERC20(collateralToken, user, fundValue);
        collateralToken.mint(user, fundValue);

        vm.startPrank(user);
        collateralToken.approve(address(tokenRouter), type(uint).max);

        vm.startPrank(users.owner);
        matchRule.deposit(collateralToken, user, fundValue);

        // Owner sets rule for puppet-trader relationship
        matchRule.setRule(
            collateralToken,
            user, // puppet address
            trader,
            MatchRule.Rule({allowanceRate: 1000, throttleActivity: 1 hours, expiry: block.timestamp + 2 days})
        );

        return user;
    }

    // Tests for error conditions
    // function testNoAllocationError() public {
    //     address trader = users.bob;
    //     uint estimatedGasLimit = 5_000_000;
    //     uint executionFee = tx.gasprice * estimatedGasLimit;

    //     // Try to mirror without allocation
    //     bytes32 mockAllocationKey = keccak256(abi.encodePacked("non-existent-allocation"));
    //     bytes32 mockSourceRequestKey = keccak256(abi.encodePacked("mock-source-request"));

    //     vm.expectRevert(Error.MirrorPosition__NoAllocation.selector);
    //     mirrorPosition.mirror{value: executionFee}(
    //         MirrorPosition.MirrorPositionParams({
    //             trader: trader,
    //             market: Address.gmxEthUsdcMarket,
    //             collateralToken: usdc,
    //             allocationKey: mockAllocationKey,
    //             sourceRequestKey: mockSourceRequestKey,
    //             isIncrease: true,
    //             isLong: true,
    //             executionFee: executionFee,
    //             collateralDelta: 100e6,
    //             sizeDeltaInUsd: 10e30,
    //             acceptablePrice: 1000e12,
    //             triggerPrice: 1000e12
    //         })
    //     );
    // }

    // function testPendingAllocationError() public {
    //     address trader = users.bob;
    //     bytes32 mockSourceRequestKey = keccak256(abi.encodePacked(users.bob, uint(0)));
    //     bytes32 matchKey = PositionUtils.getMatchKey(usdc, trader);
    //     bytes32 positionKey = keccak256(abi.encodePacked("position-1"));

    //     address[] memory puppetList = generatePuppetList(usdc, trader, 10);

    //     // Create first allocation
    //     bytes32 allocationKey =
    //         mirrorPosition.allocate(usdc, mockSourceRequestKey, matchKey, positionKey, trader, puppetList);

    //     // Try to allocate again with the same keys - should fail
    //     vm.expectRevert(Error.MirrorPosition__PendingAllocation.selector);
    //     mirrorPosition.allocate(usdc, mockSourceRequestKey, matchKey, positionKey, trader, puppetList);
    // }

    // function testPuppetListLimitError() public {
    //     address trader = users.bob;
    //     bytes32 mockSourceRequestKey = keccak256(abi.encodePacked(users.bob, uint(0)));
    //     bytes32 matchKey = PositionUtils.getMatchKey(usdc, trader);
    //     bytes32 positionKey = keccak256(abi.encodePacked("position-1"));

    //     // Use a hardcoded test value of 100 puppets for the limit
    //     // This matches the limitAllocationListLength we set in setUp()
    //     uint limitAllocationListLength = 100;

    //     // Generate a list with just 1 more than the limit
    //     // This is enough to trigger the error but avoids memory issues
    //     uint testListLength = limitAllocationListLength + 1;

    //     // Create a puppet list with the test length
    //     address[] memory tooManyPuppets = new address[](testListLength);
    //     for (uint i = 0; i < testListLength; i++) {
    //         tooManyPuppets[i] = address(uint160(i + 1)); // Simple deterministic addresses
    //     }

    //     // This should fail due to exceeding the puppet list limit
    //     vm.expectRevert(Error.MirrorPosition__PuppetListLimit.selector);
    //     mirrorPosition.allocate(usdc, mockSourceRequestKey, matchKey, positionKey, trader, tooManyPuppets);
    // }

    // function testNoPuppetAllocationError() public {
    //     address trader = users.bob;
    //     bytes32 mockSourceRequestKey = keccak256(abi.encodePacked(users.bob, uint(0)));
    //     bytes32 matchKey = PositionUtils.getMatchKey(usdc, trader);
    //     bytes32 positionKey = keccak256(abi.encodePacked("position-1"));

    //     // Create empty puppet list - should fail as no puppets to allocate from
    //     address[] memory emptyPuppetList = new address[](0);

    //     vm.expectRevert(Error.MirrorPosition__NoPuppetAllocation.selector);
    //     mirrorPosition.allocate(usdc, mockSourceRequestKey, matchKey, positionKey, trader, emptyPuppetList);
    // }

    // function testExecutionRequestMissingError() public {
    //     // Try to process a non-existent request
    //     bytes32 nonExistentRequestKey = keccak256(abi.encodePacked("non-existent-request"));

    //     vm.expectRevert(Error.MirrorPosition__ExecutionRequestMissing.selector);
    //     mirrorPosition.increase(nonExistentRequestKey);

    //     vm.expectRevert(Error.MirrorPosition__ExecutionRequestMissing.selector);
    //     mirrorPosition.decrease(nonExistentRequestKey);
    // }

    // function testPositionDoesNotExistError() public {
    //     address trader = users.bob;
    //     uint estimatedGasLimit = 5_000_000;
    //     uint executionFee = tx.gasprice * estimatedGasLimit;

    //     // Create valid allocation first
    //     bytes32 mockSourceRequestKey = keccak256(abi.encodePacked(users.bob, uint(0)));
    //     bytes32 matchKey = PositionUtils.getMatchKey(usdc, trader);
    //     bytes32 positionKey = keccak256(abi.encodePacked("position-1"));
    //     address[] memory puppetList = generatePuppetList(usdc, trader, 10);
    //     bytes32 allocationKey =
    //         mirrorPosition.allocate(usdc, mockSourceRequestKey, matchKey, positionKey, trader, puppetList);

    //     // Create a decrease order without having a position first
    //     bytes32 decreaseRequestKey = mirrorPosition.mirror{value: executionFee}(
    //         MirrorPosition.MirrorPositionParams({
    //             trader: trader,
    //             market: Address.gmxEthUsdcMarket,
    //             collateralToken: usdc,
    //             allocationKey: allocationKey,
    //             sourceRequestKey: mockSourceRequestKey,
    //             isIncrease: false, // Decrease
    //             isLong: true,
    //             executionFee: executionFee,
    //             collateralDelta: 100e6,
    //             sizeDeltaInUsd: 10e30,
    //             acceptablePrice: 1000e12,
    //             triggerPrice: 1000e12
    //         })
    //     );

    //     // This should fail when trying to decrease a non-existent position
    //     vm.expectRevert(Error.MirrorPosition__PositionDoesNotExist.selector);
    //     mirrorPosition.decrease(decreaseRequestKey);
    // }

    // function testNoSettledFundsError() public {
    //     address trader = users.bob;
    //     bytes32 mockSourceRequestKey = keccak256(abi.encodePacked(users.bob, uint(0)));
    //     bytes32 matchKey = PositionUtils.getMatchKey(usdc, trader);
    //     bytes32 positionKey = keccak256(abi.encodePacked("position-1"));

    //     address[] memory puppetList = generatePuppetList(usdc, trader, 10);
    //     bytes32 allocationKey =
    //         mirrorPosition.allocate(usdc, mockSourceRequestKey, matchKey, positionKey, trader, puppetList);

    //     // Try to settle without any funds being settled
    //     vm.expectRevert(Error.MirrorPosition__NoSettledFunds.selector);
    //     mirrorPosition.settle(allocationKey, puppetList);
    // }

    // function testInvalidPuppetListIntegrityError() public {
    //     // Run the full flow up to the point where we have settled funds
    //     address trader = users.bob;
    //     uint estimatedGasLimit = 5_000_000;
    //     uint executionFee = tx.gasprice * estimatedGasLimit;

    //     address[] memory puppetList = generatePuppetList(usdc, trader, 10);
    //     address[] memory differentPuppetList = generatePuppetList(usdc, trader, 8); // Different list

    //     bytes32 mockSourceRequestKey = keccak256(abi.encodePacked(users.bob, uint(0)));
    //     bytes32 matchKey = PositionUtils.getMatchKey(usdc, trader);
    //     bytes32 positionKey = keccak256(abi.encodePacked("position-1"));

    //     bytes32 allocationKey =
    //         mirrorPosition.allocate(usdc, mockSourceRequestKey, matchKey, positionKey, trader, puppetList);

    //     bytes32 increaseRequestKey = mirrorPosition.mirror{value: executionFee}(
    //         MirrorPosition.MirrorPositionParams({
    //             trader: trader,
    //             market: Address.gmxEthUsdcMarket,
    //             collateralToken: usdc,
    //             allocationKey: allocationKey,
    //             sourceRequestKey: mockSourceRequestKey,
    //             isIncrease: true,
    //             isLong: true,
    //             executionFee: executionFee,
    //             collateralDelta: 120e6,
    //             sizeDeltaInUsd: 30e30,
    //             acceptablePrice: 1000e12,
    //             triggerPrice: 1000e12
    //         })
    //     );

    //     // Simulate position increase callback
    //     mirrorPosition.increase(increaseRequestKey);

    //     // Create decrease request
    //     bytes32 decreaseRequestKey = mirrorPosition.mirror{value: executionFee}(
    //         MirrorPosition.MirrorPositionParams({
    //             trader: trader,
    //             market: Address.gmxEthUsdcMarket,
    //             collateralToken: usdc,
    //             allocationKey: allocationKey,
    //             sourceRequestKey: mockSourceRequestKey,
    //             isIncrease: false,
    //             isLong: true,
    //             executionFee: executionFee,
    //             collateralDelta: 120e6,
    //             sizeDeltaInUsd: 30e30,
    //             acceptablePrice: 1000e12,
    //             triggerPrice: 1000e12
    //         })
    //     );

    //     // Simulate funds coming back
    //     deal(address(usdc), address(subaccountStore), usdc.balanceOf(address(subaccountStore)) + 11e6 * 10);

    //     // Simulate position decrease callback
    //     mirrorPosition.decrease(decreaseRequestKey);

    //     // Now try to settle with a different puppet list than the one used for allocation
    //     vm.expectRevert(Error.MirrorPosition__InvalidPuppetListIntegrity.selector);
    //     mirrorPosition.settle(allocationKey, differentPuppetList);
    // }

    // Functional tests
    // function testSizeAdjustmentsMatchMirrorPostion() public {
    //     address trader = users.bob;
    //     uint estimatedGasLimit = 5_000_000;
    //     uint executionFee = tx.gasprice * estimatedGasLimit;

    //     address[] memory puppetList = generatePuppetList(usdc, trader, 2);

    //     bytes32 mockSourceRequestKey = keccak256(abi.encodePacked(users.bob, uint(0)));
    //     bytes32 matchKey = PositionUtils.getMatchKey(usdc, trader);
    //     bytes32 positionKey = keccak256(abi.encodePacked("position-1"));

    //     bytes32 allocationKey =
    //         mirrorPosition.allocate(usdc, mockSourceRequestKey, matchKey, positionKey, trader, puppetList);

    //     // Open position
    //     bytes32 increaseRequestKey = mirrorPosition.mirror{value: executionFee}(
    //         MirrorPosition.MirrorPositionParams({
    //             trader: trader,
    //             market: Address.gmxEthUsdcMarket,
    //             collateralToken: usdc,
    //             allocationKey: allocationKey,
    //             sourceRequestKey: mockSourceRequestKey,
    //             isIncrease: true,
    //             isLong: true,
    //             executionFee: executionFee,
    //             collateralDelta: 100e6,
    //             sizeDeltaInUsd: 1000e30,
    //             acceptablePrice: 1000e12,
    //             triggerPrice: 1000e12
    //         })
    //     );

    //     // make sure request includes the propotional size and collateral to the puppet

    //     // test case has 2 puppets. trader initial target ratio is 1000e30 / 100e6 = 10x
    //     // each collateral delta should be 10 USDC due to 10% allocation rule
    //     // the combined collateral delta should be 20 USDC
    //     // size should be 200e30 to match trader 10x target ratio
    //     assertEq(
    //         mirrorPosition.getRequestAdjustment(increaseRequestKey).puppetSizeDelta,
    //         200e30,
    //         "Initial size delta should be 200e30 as each puppet"
    //     );

    //     mirrorPosition.increase(increaseRequestKey);

    //     MirrorPosition.Position memory _position1 = mirrorPosition.getPosition(allocationKey);

    //     assertEq(_position1.traderSize, 1000e30, "Trader size should be 1000e30");
    //     assertEq(_position1.tradercollateral, 100e6, "Trader collateral should be 100e6");
    //     assertEq(_position1.mpSize, 200e30, "MirrorPosition size should be 200e30");
    //     assertEq(_position1.mpCollateral, 20e6, "MirrorPosition collateral should be 20e6");

    //     assertEq(
    //         Precision.toBasisPoints(_position1.traderSize, _position1.tradercollateral),
    //         Precision.toBasisPoints(_position1.mpSize, _position1.mpCollateral),
    //         "Trader and MirrorPosition size should be equal"
    //     );

    //     // // Partial decrease (50%)
    //     bytes32 partialDecreaseRequestKey = mirrorPosition.mirror{value: executionFee}(
    //         MirrorPosition.MirrorPositionParams({
    //             trader: trader,
    //             market: Address.gmxEthUsdcMarket,
    //             collateralToken: usdc,
    //             allocationKey: allocationKey,
    //             sourceRequestKey: mockSourceRequestKey,
    //             isIncrease: false,
    //             isLong: true,
    //             executionFee: executionFee,
    //             collateralDelta: 0, // No collateral change
    //             sizeDeltaInUsd: 500e30, // 50% of size
    //             acceptablePrice: 1000e12,
    //             triggerPrice: 1000e12
    //         })
    //     );

    //     assertEq(
    //         mirrorPosition.getRequestAdjustment(partialDecreaseRequestKey).puppetSizeDelta,
    //         100e30,
    //         "For a 50% position decrease, puppet size delta should be 100e30 (50% of total)"
    //     );

    //     mirrorPosition.decrease(partialDecreaseRequestKey);

    //     MirrorPosition.Position memory _position2 = mirrorPosition.getPosition(allocationKey);

    //     assertEq(_position2.traderSize, 500e30, "Trader size should be 500e30");
    //     assertEq(_position2.tradercollateral, 100e6, "Trader collateral should remain 100e6");

    //     assertEq(
    //         Precision.toBasisPoints(_position2.traderSize, _position2.tradercollateral),
    //         Precision.toBasisPoints(_position2.mpSize, _position2.mpCollateral),
    //         "Trader and MirrorPosition size should be equal"
    //     );

    //     // Partial increase (50%)
    //     bytes32 partialIncreaseRequestKey = mirrorPosition.mirror{value: executionFee}(
    //         MirrorPosition.MirrorPositionParams({
    //             trader: trader,
    //             market: Address.gmxEthUsdcMarket,
    //             collateralToken: usdc,
    //             allocationKey: allocationKey,
    //             sourceRequestKey: mockSourceRequestKey,
    //             isIncrease: true,
    //             isLong: true,
    //             executionFee: executionFee,
    //             collateralDelta: 0, // No collateral change
    //             sizeDeltaInUsd: 500e30, // 50% of size
    //             acceptablePrice: 1000e12,
    //             triggerPrice: 1000e12
    //         })
    //     );

    //     mirrorPosition.increase(partialIncreaseRequestKey);

    //     MirrorPosition.Position memory _position3 = mirrorPosition.getPosition(allocationKey);

    //     assertEq(_position3.traderSize, 1000e30, "Trader size should be 1000e30 after partial increase");
    //     assertEq(_position3.tradercollateral, 100e6, "Trader collateral should remain 100e6 after partial increase");
    //     assertEq(_position3.mpSize, 200e30, "MirrorPosition size should get back to 200e30 after partial increase");

    //     assertEq(
    //         Precision.toBasisPoints(_position3.traderSize, _position3.tradercollateral),
    //         Precision.toBasisPoints(_position3.mpSize, _position3.mpCollateral),
    //         "Trader and MirrorPosition size should be equal"
    //     );

    //     // add more tests with collateral adjustments in testAdjustmentsMatchMirrorPostion()

    //     // Full decrease
    //     bytes32 fullDecreaseRequestKey = mirrorPosition.mirror{value: executionFee}(
    //         MirrorPosition.MirrorPositionParams({
    //             trader: trader,
    //             market: Address.gmxEthUsdcMarket,
    //             collateralToken: usdc,
    //             allocationKey: allocationKey,
    //             sourceRequestKey: mockSourceRequestKey,
    //             isIncrease: false,
    //             isLong: true,
    //             executionFee: executionFee,
    //             collateralDelta: 0, // No collateral change
    //             sizeDeltaInUsd: 1000e30, // Full size
    //             acceptablePrice: 1000e12,
    //             triggerPrice: 1000e12
    //         })
    //     );
    //     mirrorPosition.decrease(fullDecreaseRequestKey);
    //     MirrorPosition.Position memory _position4 = mirrorPosition.getPosition(allocationKey);
    //     assertEq(_position4.traderSize, 0, "Trader size should be 0 after full decrease");
    //     assertEq(_position4.tradercollateral, 0, "Trader collateral should be 0 after full decrease");
    //     assertEq(_position4.mpSize, 0, "MirrorPosition size should be 0 after full decrease");
    //     assertEq(_position4.mpCollateral, 0, "MirrorPosition collateral should be 0 after full decrease");
    // }

    function testCollateralAdjustmentsMatchMirrorPostion() public {
        address trader = users.bob;
        uint estimatedGasLimit = 5_000_000;
        uint executionFee = tx.gasprice * estimatedGasLimit;

        address[] memory puppetList = generatePuppetList(usdc, trader, 2);

        bytes32 mockSourceRequestKey = keccak256(abi.encodePacked(users.bob, uint(0)));
        bytes32 matchKey = PositionUtils.getMatchKey(usdc, trader);
        bytes32 positionKey = keccak256(abi.encodePacked("position-1"));

        bytes32 allocationKey =
            mirrorPosition.allocate(usdc, mockSourceRequestKey, matchKey, positionKey, trader, puppetList);

        // Open position
        bytes32 increaseRequestKey = mirrorPosition.mirror{value: executionFee}(
            MirrorPosition.MirrorPositionParams({
                trader: trader,
                market: Address.gmxEthUsdcMarket,
                collateralToken: usdc,
                allocationKey: allocationKey,
                sourceRequestKey: mockSourceRequestKey,
                isIncrease: true,
                isLong: true,
                executionFee: executionFee,
                collateralDelta: 100e6,
                sizeDeltaInUsd: 1000e30,
                acceptablePrice: 1000e12,
                triggerPrice: 1000e12
            })
        );

        // make sure request includes the propotional size and collateral to the puppet

        // test case has 2 puppets. trader initial target ratio is 1000e30 / 100e6 = 10x
        // each collateral delta should be 10 USDC due to 10% allocation rule
        // the combined collateral delta should be 20 USDC
        // size should be 200e30 to match trader 10x target ratio
        assertEq(
            mirrorPosition.getRequestAdjustment(increaseRequestKey).puppetCollateralDelta,
            20e6,
            "Initial size delta should be 20e6 as each puppet"
        );

        mirrorPosition.increase(increaseRequestKey);

        MirrorPosition.Position memory _position1 = mirrorPosition.getPosition(allocationKey);

        assertEq(_position1.traderSize, 1000e30, "Trader size should be 1000e30");
        assertEq(_position1.traderCollateral, 100e6, "Trader collateral should be 100e6");
        assertEq(_position1.mpSize, 200e30, "MirrorPosition size should be 200e30");
        assertEq(_position1.mpCollateral, 20e6, "MirrorPosition collateral should be 20e6");
        assertEq(
            Precision.toBasisPoints(_position1.traderSize, _position1.traderCollateral),
            Precision.toBasisPoints(_position1.mpSize, _position1.mpCollateral),
            "Trader and MirrorPosition size should be equal"
        );
        // // Partial Increase (50%)
        bytes32 partialIncreaseRequestKey = mirrorPosition.mirror{value: executionFee}(
            MirrorPosition.MirrorPositionParams({
                trader: trader,
                market: Address.gmxEthUsdcMarket,
                collateralToken: usdc,
                allocationKey: allocationKey,
                sourceRequestKey: mockSourceRequestKey,
                isIncrease: true,
                isLong: true,
                executionFee: executionFee,
                collateralDelta: 100e6, // +100% collateral
                sizeDeltaInUsd: 0, // No size change
                acceptablePrice: 1000e12,
                triggerPrice: 1000e12
            })
        );
        
        assertEq(
            mirrorPosition.getRequestAdjustment(partialIncreaseRequestKey).puppetSizeDelta,
            100e30,
            "For a 50% collateral decrease, puppet size delta should adjust by 100e30 (50% of total)"
        );
        mirrorPosition.decrease(partialIncreaseRequestKey);
        MirrorPosition.Position memory _position2 = mirrorPosition.getPosition(allocationKey);
        assertEq(_position2.traderSize, 1000e30, "Trader size should be 1000e30");
        assertEq(_position2.traderCollateral, 200e6, "Trader collateral should be 200e6");
        assertEq(_position2.mpSize, 100e30, "MirrorPosition size should be 100e30");
        assertEq(_position2.mpCollateral, 20e6, "MirrorPosition collateral should remain 20e6");
        assertEq(
            Precision.toBasisPoints(_position2.traderSize, _position2.traderCollateral),
            Precision.toBasisPoints(_position2.mpSize, _position2.mpCollateral),
            "Trader and MirrorPosition size should be equal"
        );

    }

    // function testGasFeeTracking() public {
    //     // Set a non-zero gas price for the test (default is 0 in Foundry)
    //     uint testGasPrice = 100 gwei; // 100 gwei
    //     vm.txGasPrice(testGasPrice);

    //     address trader = users.bob;
    //     uint estimatedGasLimit = 5_000_000;
    //     uint executionFee = testGasPrice * estimatedGasLimit; // Use our set gas price

    //     console.log("Test Gas Price:", testGasPrice);
    //     console.log("Execution Fee:", executionFee);
    //     console.log("Current tx.gasprice:", tx.gasprice);

    //     address[] memory puppetList = generatePuppetList(usdc, trader, 5);

    //     bytes32 mockSourceRequestKey = keccak256(abi.encodePacked(users.bob, uint(0)));
    //     bytes32 matchKey = PositionUtils.getMatchKey(usdc, trader);
    //     bytes32 positionKey = keccak256(abi.encodePacked("position-1"));

    //     // Track gas before allocation
    //     uint gasBefore = gasleft();
    //     bytes32 allocationKey =
    //         mirrorPosition.allocate(usdc, mockSourceRequestKey, matchKey, positionKey, trader, puppetList);
    //     uint gasUsedAllocation = gasBefore - gasleft();
    //     console.log("Gas Used for Allocation:", gasUsedAllocation);

    //     // Check allocation gas tracking
    //     (,,,,,, uint allocationGasFee,) = mirrorPosition.allocationMap(allocationKey);
    //     console.log("Recorded Allocation Gas Fee:", allocationGasFee);
    //     console.log("Expected Allocation Gas Fee:", gasUsedAllocation * testGasPrice);

    //     assertGt(allocationGasFee, 0, "Allocation gas fee should be tracked");
    //     // The contract's internal gas tracking doesn't measure exactly the same gas usage as our test
    //     // because it only tracks specific operations within the allocation function.
    //     // We'll check that it's within a reasonable range (at least 50% of the expected value)
    //     uint expectedMinimumGasFee = (gasUsedAllocation * testGasPrice) / 2;
    //     assertGt(allocationGasFee, expectedMinimumGasFee, "Allocation gas fee should be reasonably close to
    // expected");

    //     // Track gas before mirroring
    //     uint gasFeeBeforeMirror = allocationGasFee;
    //     bytes32 increaseRequestKey = mirrorPosition.mirror{value: executionFee}(
    //         MirrorPosition.MirrorPositionParams({
    //             trader: trader,
    //             market: Address.gmxEthUsdcMarket,
    //             collateralToken: usdc,
    //             allocationKey: allocationKey,
    //             sourceRequestKey: mockSourceRequestKey,
    //             isIncrease: true,
    //             isLong: true,
    //             executionFee: executionFee,
    //             collateralDelta: 120e6,
    //             sizeDeltaInUsd: 100e30,
    //             acceptablePrice: 1000e12,
    //             triggerPrice: 1000e12
    //         })
    //     );

    //     // Check execution gas tracking
    //     uint executionGasFee;
    //     (,,,,,, allocationGasFee, executionGasFee) = mirrorPosition.allocationMap(allocationKey);
    //     console.log("Execution Gas Fee:", executionGasFee);
    //     console.log("Minimum Expected Execution Fee:", executionFee);

    //     assertEq(allocationGasFee, gasFeeBeforeMirror, "Allocation gas fee should remain unchanged");
    //     assertGt(executionGasFee, 0, "Execution gas fee should be tracked");
    //     // Execution gas fee includes the provided executionFee
    //     assertGe(executionGasFee, executionFee, "Execution gas fee should be at least the execution fee");
    // }

    // Helper functions for tests
    function getPerformanceFee() internal returns (uint) {
        (,,,,,, uint performanceFee, uint traderPerformanceFee,) = mirrorPosition.config();
        return performanceFee;
    }

    function setPerformanceFee(
        uint newFee
    ) internal {
        (
            IGmxExchangeRouter gmxExchangeRouter,
            address callbackHandler,
            address gmxOrderVault,
            bytes32 referralCode,
            uint increaseCallbackGasLimit,
            uint decreaseCallbackGasLimit,
            uint limitAllocationListLength,
            ,
            uint traderPerformanceFee
        ) = mirrorPosition.config();

        dictator.setConfig(
            mirrorPosition,
            abi.encode(
                MirrorPosition.Config({
                    gmxExchangeRouter: gmxExchangeRouter,
                    callbackHandler: callbackHandler,
                    gmxOrderVault: gmxOrderVault,
                    referralCode: referralCode,
                    increaseCallbackGasLimit: increaseCallbackGasLimit,
                    decreaseCallbackGasLimit: decreaseCallbackGasLimit,
                    limitAllocationListLength: limitAllocationListLength,
                    performanceFee: newFee,
                    traderPerformanceFee: traderPerformanceFee
                })
            )
        );
    }
}
