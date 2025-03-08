// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {MatchRule} from "src/position/MatchRule.sol";
import {MirrorPosition} from "src/position/MirrorPosition.sol";
import {IGmxExchangeRouter} from "src/position/interface/IGmxExchangeRouter.sol";
import {IGmxOracle} from "src/position/interface/IGmxOracle.sol";
import {GmxPositionUtils} from "src/position/utils/GmxPositionUtils.sol";
import {PositionUtils} from "src/position/utils/PositionUtils.sol";

import {Subaccount} from "src/shared/Subaccount.sol";
import {SubaccountStore} from "src/shared/SubaccountStore.sol";
import {FeeMarketplace} from "src/tokenomics/FeeMarketplace.sol";
import {FeeMarketplaceStore} from "src/tokenomics/store/FeeMarketplaceStore.sol";

import {Address} from "script/Const.sol";

import {BasicSetup} from "../base/BasicSetup.t.sol";
import {MockGmxExchangeRouter} from "../mock/MockGmxExchangeRouter.sol";

contract TradingTest is BasicSetup {
    SubaccountStore subaccountStore;
    MatchRule matchRule;
    FeeMarketplace feeMarketplace;
    MirrorPosition mirrorPosition;
    IGmxExchangeRouter gmxExchangeRouter;
    MockGmxExchangeRouter mockGmxExchangeRouter;
    FeeMarketplaceStore feeMarketplaceStore;

    IGmxOracle gmxOracle = IGmxOracle(Address.gmxOracle);

    function setUp() public override {
        super.setUp();

        mockGmxExchangeRouter = new MockGmxExchangeRouter();

        // Deploy core contracts
        subaccountStore = new SubaccountStore(dictator, tokenRouter);
        matchRule = new MatchRule(dictator, subaccountStore);
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
                    rewardDistributor: address(0)
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
                    performanceContributionRate: 0.1e30,
                    traderPerformanceContributionShare: 0
                })
            )
        );

        dictator.setPermission(tokenRouter, tokenRouter.transfer.selector, address(subaccountStore));
        dictator.setAccess(subaccountStore, address(matchRule));
        dictator.setAccess(subaccountStore, address(mirrorPosition));

        // Set permissions
        dictator.setPermission(mirrorPosition, mirrorPosition.allocate.selector, users.owner);
        dictator.setPermission(mirrorPosition, mirrorPosition.mirror.selector, users.owner);
        dictator.setPermission(mirrorPosition, mirrorPosition.settle.selector, users.owner);
        dictator.setPermission(mirrorPosition, mirrorPosition.increase.selector, users.owner);
        dictator.setPermission(mirrorPosition, mirrorPosition.decrease.selector, users.owner);

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

    function testExecution() public {
        address trader = users.bob;

        uint estimatedGasLimit = 5_000_000;
        uint executionFee = tx.gasprice * estimatedGasLimit;

        address[] memory puppetList = getGeneratePuppetList(usdc, trader, 10);

        bytes32 mockSourceRequestKey = keccak256(abi.encodePacked(users.bob, uint(0)));
        bytes32 matchKey = PositionUtils.getMatchKey(usdc, trader);
        bytes32 positionKey = keccak256(abi.encodePacked("position-1"));
        bytes32 allocationKey = mirrorPosition.allocate(usdc, mockSourceRequestKey, matchKey, positionKey, puppetList);


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
                collateralDelta: 1e18,
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
                collateralDelta: 1e18,
                sizeDeltaInUsd: 30e30,
                acceptablePrice: 1000e12,
                triggerPrice: 1000e12
            })
        );

        // Need to simulate some tokens coming back to the contract
        // In real environment, GMX would send funds back
        deal(address(usdc), address(subaccountStore), 2e18); // Return more than collateral to simulate profit

        // Simulate position decrease callback
        mirrorPosition.decrease(decreaseRequestKey);

        // Settle the allocation
        mirrorPosition.settle(allocationKey, puppetList);
    }

    function getGeneratePuppetList(
        IERC20 collateralToken,
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
        IERC20 collateralToken,
        address trader,
        string memory name,
        uint fundValue
    ) internal returns (address payable) {
        address payable user = payable(makeAddr(name));
        _dealERC20(address(collateralToken), user, fundValue);

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
}
