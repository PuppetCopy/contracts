// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {PuppetToken} from "src/tokenomics/PuppetToken.sol";

import {Precision} from "src/utils/Precision.sol";

import {BasicSetup} from "test/base/BasicSetup.t.sol";
import {MockWeightedPoolVault} from "test/mocks/MockWeightedPoolVault.sol";

import {VotingEscrow, MAXTIME} from "src/tokenomics/VotingEscrow.sol";
import {RewardStore} from "src/tokenomics/store/RewardStore.sol";
import {RevenueStore} from "src/tokenomics/store/RevenueStore.sol";
import {RewardLogic} from "src/tokenomics/RewardLogic.sol";
import {RevenueLogic} from "src/tokenomics/RevenueLogic.sol";

contract RewardLogicTest is BasicSetup {
    VotingEscrow votingEscrow;
    MockWeightedPoolVault primaryVaultPool;
    RewardStore rewardStore;
    RevenueStore revenueStore;

    RewardLogic rewardLogic;
    RevenueLogic revenueLogic;

    RewardLogic.Config public config = RewardLogic.Config({
        baselineEmissionRate: 1e30,
        lockLiquidTokensBonusMultiplier: 1e30,
        optionLockTokensBonusMultiplier: 1e30,
        distributionTimeframe: 1 weeks
    });

    function setUp() public override {
        vm.warp(1716671477);

        super.setUp();

        votingEscrow = new VotingEscrow(dictator, router, puppetToken);
        dictator.setAccess(router, address(votingEscrow));

        IERC20[] memory _buybackTokenList = new IERC20[](2);
        _buybackTokenList[0] = wnt;
        _buybackTokenList[1] = usdc;

        uint[] memory _buybackOfferAmountList = new uint[](2);
        _buybackOfferAmountList[0] = 1e18;
        _buybackOfferAmountList[1] = 1000e30;

        revenueStore = new RevenueStore(dictator, router, _buybackTokenList, _buybackOfferAmountList);
        dictator.setAccess(router, address(revenueStore));

        rewardStore = new RewardStore(dictator, router);

        revenueLogic = new RevenueLogic(dictator, puppetToken, revenueStore);
        dictator.setAccess(revenueStore, address(revenueLogic));

        rewardLogic = new RewardLogic(dictator, votingEscrow, puppetToken, rewardStore, revenueStore, config);
        dictator.setAccess(rewardStore, address(rewardLogic));
        dictator.setPermission(votingEscrow, address(rewardLogic), votingEscrow.lock.selector);
        dictator.setPermission(votingEscrow, address(rewardLogic), votingEscrow.vest.selector);
        dictator.setPermission(votingEscrow, address(rewardLogic), votingEscrow.claim.selector);
        dictator.setPermission(puppetToken, address(rewardLogic), puppetToken.mint.selector);

        // permissions used for testing
        vm.startPrank(users.owner);
        dictator.setAccess(revenueStore, users.owner);
        dictator.setPermission(revenueLogic, users.owner, revenueLogic.buybackRevenue.selector);
        wnt.approve(address(router), type(uint).max - 1);
        puppetToken.approve(address(router), type(uint).max - 1);
    }

    function testBuybackToken() public {
        vm.startPrank(users.owner);

        // Arrange: Set up the initial state
        uint revenueAmount = 1e18; // 1 Other Token
        uint thresholdAmount = revenueStore.getTokenBuybackOffer(wnt);

        userContribute(wnt, revenueAmount);

        revenueLogic.buybackRevenue(users.owner, users.owner, wnt, revenueAmount);

        // Assert: Check the final state
        assertEq(puppetToken.balanceOf(address(revenueStore)), thresholdAmount, "Puppet token balance should be increased by the buyback amount");
        assertEq(wnt.balanceOf(users.owner), revenueAmount, "Other token balance should be reduced by the buyback amount");
    }

    // function testExitOption() public {
    //     vm.startPrank(users.alice);
    // }

    // function testLockOption() public {
    //     lock(wnt, users.yossi, MAXTIME, 1e18);
    //     skip(rewardRouterConfig.distributionTimeframe);
    //     skip(rewardRouterConfig.distributionTimeframe);

    //     lock(wnt, users.alice, MAXTIME, 1e18);
    //     skip(rewardRouterConfig.distributionTimeframe);

    //     assertApproxEqAbs(rewardRouter.getClaimableEmission(wnt, users.yossi), 1.5e18, 0.1e18);
    //     assertApproxEqAbs(rewardRouter.getClaimableEmission(wnt, users.alice), 0.5e18, 0.1e18);

    //     assertApproxEqAbs(rewardRouter.getClaimableEmission(wnt, users.alice) + rewardRouter.getClaimableEmission(wnt, users.yossi), 2e18,
    // 0.001e18);
    //     // assertEq(
    //     //     votingEscrow.balanceOf(users.yossi) + votingEscrow.balanceOf(users.alice),
    //     //     votingEscrow.totalSupply()
    //     // );

    //     // skip(rewardRouterConfig.distributionTimeframe / 2);

    //     // assertApproxEqAbs(rewardRouter.getClaimable(wnt, users.yossi), 1.5e18, 0.01e18);
    //     // assertApproxEqAbs(rewardRouter.getClaimable(wnt, users.alice), 0.5e18, 0.01e18);

    //     // assertApproxEqAbs(rewardRouter.claim(wnt, users.alice), 0.5e18, 0.01e18);
    //     // assertEq(rewardRouter.getClaimable(wnt, users.alice), 0);

    //     // // lock(wnt, users.alice, getMaxTime(), 0.01e18, 1e18);
    //     // skip(rewardRouterConfig.distributionTimeframe / 2);
    //     // lock(wnt, users.bob, getMaxTime(), 0.01e18, 1e18);

    //     // assertApproxEqAbs(rewardRouter.getClaimable(wnt, users.yossi), 0.125e18, 0.01e18);

    //     // assertApproxEqAbs(rewardRouter.getClaimable(wnt, users.bob), 0.125e18, 0.01e18);

    //     // skip(rewardRouterConfig.distributionTimeframe / 2);

    //     // assertApproxEqAbs(rewardRouter.getClaimable(wnt, users.bob), 0.25e18, 0.01e18);
    // }

    // function testHistoricBalances() public {
    //     skip(1 weeks);
    //     lock(wnt, users.alice, getMaxTime(), 0.01e18, 0.5e18);
    //     lock(wnt, users.bob, getMaxTime(), 0.01e18, 0.5e18);

    //     skip(rewardRouterConfig.distributionTimeframe);

    //     assertApproxEqAbs(claim(wnt, users.alice), 0.75e18, 0.01e18);
    //     // assertApproxEqAbs(claim(wnt, users.bob), 0.25e18, 0.01e18);

    //     // skip(rewardRouterConfig.distributionTimeframe / 2);
    //     // assertApproxEqAbs(claim(wnt, users.yossi), 1e18, 0.01e18);

    //     // // dust case
    //     // lock(wnt, users.bob, getMaxTime(), 0.01e18, 1e18);
    //     // skip(rewardRouterConfig.distributionTimeframe / 2);

    //     // assertApproxEqAbs(rewardRouter.getClaimable(wnt, users.yossi), 0.5e18, 0.01e18);

    //     // include withdraw flow
    // }

    // function testCrossedFlow() public {

    //         generateUserRevenue(wnt, users.alice, 1e18);
    // assertEq(getLockClaimableAmount(wnt, users.alice), 60e18);
    // generateUserRevenue(usdc, users.alice, 100e6);
    // assertEq(getLockClaimableAmount(usdc, users.alice), 60e18);
    //     generateUserRevenue(wnt, users.alice, 1e18);
    //     exit(wnt, 0.01e18, 1e18, users.alice);
    //     generateUserRevenue(usdc, users.alice, 100e6);
    //     lock(usdc, getMaxTime(), 1e6, 100e6);
    //     assertEq(puppetToken.balanceOf(users.alice), 30e18);

    //     generateUserRevenue(usdc, users.bob, 100e6);
    //     assertEq(getLockClaimableAmount(usdc, users.bob), 60e18);
    //     assertEq(getExitClaimableAmount(usdc, users.bob), 30e18);
    //     exit(usdc, 1e6, 100e6, users.bob);
    //     assertEq(puppetToken.balanceOf(users.bob), 30e18);

    //     generateUserRevenue(usdc, users.bob, 100e6);
    //     assertEq(getLockClaimableAmount(usdc, users.bob), 60e18);
    //     lock(usdc, getMaxTime() / 2, 1e6, 100e6);
    //     assertApproxEqAbs(votingEscrow.balanceOf(users.bob), Precision.applyBasisPoints(lockRate, 100e18) / 4, 0.05e18);
    // }

    // function testVestingDecay() public {
    //     skip(1 weeks);
    //     generateUserRevenue(wnt, users.yossi, 1e18);
    //     lock(wnt, getMaxTime(), 0.01e18, 1e18);

    //     generateUserRevenue(wnt, users.alice, 1e18);
    //     skip(1 days);
    //     lock(wnt, getMaxTime(), 0.01e18, 1e18);

    //     assertEq(rewardRouter.getClaimableCursor(wnt, users.yossi, 1 weeks), 1e18);

    //     skip(1 weeks);

    //     generateUserRevenue(wnt, users.bob, 1e18);
    //     lock(wnt, getMaxTime(), 0.01e18, 1e18);
    //     skip(1 weeks);

    //     assertEq(rewardRouter.getClaimableCursor(wnt, users.yossi, 1 weeks), 1e18);
    //     assertEq(rewardRouter.getClaimableCursor(wnt, users.alice, 1 weeks), 1e18);
    //     assertApproxEqAbs(rewardRouter.getClaimable(wnt, users.alice), 1.333e18, 0.05e18);
    //     assertApproxEqAbs(rewardRouter.getClaimable(wnt, users.yossi), 1.333e18, 0.05e18);
    //     assertApproxEqAbs(rewardRouter.getClaimable(wnt, users.bob), 0.33e18, 0.05e18);

    //     skip(MAXTIME / 2);
    //     assertEq(rewardRouter.getClaimableCursor(wnt, users.yossi, 1 weeks), 1e18);
    //     assertEq(rewardRouter.getClaimableCursor(wnt, users.alice, 1 weeks), 1e18);
    //     assertApproxEqAbs(rewardRouter.getClaimable(wnt, users.alice), 1.333e18, 0.05e18);
    //     assertApproxEqAbs(rewardRouter.getClaimable(wnt, users.yossi), 1.333e18, 0.05e18);
    //     assertApproxEqAbs(claim(wnt, users.bob), 0.333e18, 0.05e18);
    //     assertEq(rewardRouter.getClaimable(wnt, users.bob), 0);

    //     generateUserRevenue(wnt, users.bob, 2e18);
    //     lock(wnt, getMaxTime(), 0.01e18, 2e18);
    //     skip(1 weeks);

    //     assertApproxEqAbs(rewardRouter.getClaimable(wnt, users.bob), 1.525e18, 0.05e18);
    // }

    function contributeEth(uint amount) public {
        uint ethPerPuppet = 0.001e18;
        uint thresholdAmount = revenueStore.getTokenBuybackOffer(wnt);

        userContribute(wnt, amount);
        buybackEth(amount);
    }

    function buybackEth(uint amount) public {
        uint ethPerPuppet = 0.001e18;
        uint thresholdAmount = revenueStore.getTokenBuybackOffer(wnt);

        uint revenue = revenueLogic.getRevenueBalance(wnt);

        if ((revenue / ethPerPuppet) >= thresholdAmount) {
            revenueLogic.buybackRevenue(users.owner, users.owner, wnt, amount);
        }
    }

    function userContribute(IERC20 token, uint amount) public {
        _dealERC20(address(token), users.owner, amount);
        revenueStore.commitReward(token, users.owner, msg.sender, amount);

        // skip block
        vm.roll(block.number + 1);
    }

    function lock(IERC20 token, address user, uint lockDuration, uint amount) public returns (uint) {
        rewardLogic.distributeEmission(token);

        uint claimableInToken = rewardLogic.lock(token, lockDuration);

        return claimableInToken;
    }

    function exit(IERC20 token, address user, uint cugarAmount) public returns (uint) {
        // uint claimableInToken = rewardRouter.exitOption(token, cugarAmount, user);

        return 0;
    }

    function claim(IERC20 token, address user) public returns (uint) {
        vm.startPrank(user);

        return rewardLogic.claimEmission(token, user);
    }

    function fromPriceToSqrt(uint usdcPerWeth) public pure returns (uint160) {
        return uint160(Math.sqrt(usdcPerWeth * 1e12) << 96) / 1e12 + 1;
    }
}
