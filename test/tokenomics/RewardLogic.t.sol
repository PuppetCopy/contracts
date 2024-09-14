// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {RewardRouter} from "src/RewardRouter.sol";
import {ContributeLogic} from "src/tokenomics/ContributeLogic.sol";
import {PuppetToken} from "src/tokenomics/PuppetToken.sol";
import {RewardLogic} from "src/tokenomics/RewardLogic.sol";
import {VotingEscrowLogic} from "src/tokenomics/VotingEscrowLogic.sol";
import {ContributeStore} from "src/tokenomics/store/ContributeStore.sol";
import {RewardStore} from "src/tokenomics/store/RewardStore.sol";
import {VotingEscrowStore} from "src/tokenomics/store/VotingEscrowStore.sol";
import {BasicSetup} from "test/base/BasicSetup.t.sol";
import {MockWeightedPoolVault} from "test/mocks/MockWeightedPoolVault.sol";

contract RewardRouterTest is BasicSetup {
    uint constant MAXTIME = 106 weeks; // about 2 years

    VotingEscrowLogic veLogic;
    MockWeightedPoolVault primaryVaultPool;
    RewardStore rewardStore;
    ContributeStore contributeStore;
    RewardLogic rewardLogic;
    ContributeLogic contributeLogic;
    VotingEscrowStore veStore;
    RewardRouter rewardRouter;

    IERC20[] claimableTokenList = new IERC20[](2);

    function setUp() public override {
        vm.warp(1716671477);

        super.setUp();

        claimableTokenList[0] = wnt;
        claimableTokenList[1] = usdc;

        veStore = new VotingEscrowStore(dictator, router);
        dictator.setPermission(router, router.transfer.selector, address(veStore));

        allowNextLoggerAccess();
        veLogic = new VotingEscrowLogic(
            dictator,
            eventEmitter,
            veStore,
            puppetToken,
            vPuppetToken,
            VotingEscrowLogic.Config({baseMultiplier: 0.6e30})
        );
        dictator.setAccess(veStore, address(veLogic));
        dictator.setPermission(puppetToken, puppetToken.mint.selector, address(veLogic));
        dictator.setPermission(vPuppetToken, vPuppetToken.mint.selector, address(veLogic));
        dictator.setPermission(vPuppetToken, vPuppetToken.burn.selector, address(veLogic));

        contributeStore = new ContributeStore(dictator, router);
        rewardStore = new RewardStore(dictator, router);
        dictator.setAccess(contributeStore, address(rewardStore));

        allowNextLoggerAccess();
        contributeLogic = new ContributeLogic(
            dictator, eventEmitter, puppetToken, contributeStore, ContributeLogic.Config({baselineEmissionRate: 0.5e30})
        );
        dictator.setPermission(puppetToken, puppetToken.mint.selector, address(contributeLogic));
        dictator.setAccess(contributeStore, address(contributeLogic));

        dictator.setPermission(router, router.transfer.selector, address(contributeStore));
        dictator.setPermission(router, router.transfer.selector, address(rewardStore));
        dictator.setPermission(router, router.transfer.selector, address(veStore));

        allowNextLoggerAccess();
        rewardLogic = new RewardLogic(
            dictator,
            eventEmitter,
            puppetToken,
            vPuppetToken,
            rewardStore,
            RewardLogic.Config({distributionStore: contributeStore, distributionTimeframe: 1 weeks})
        );
        dictator.setAccess(rewardStore, address(rewardLogic));

        allowNextLoggerAccess();
        rewardRouter = new RewardRouter(
            dictator,
            eventEmitter,
            RewardRouter.Config({contributeLogic: contributeLogic, rewardLogic: rewardLogic, veLogic: veLogic})
        );

        dictator.setPermission(contributeLogic, contributeLogic.buyback.selector, address(rewardRouter));
        dictator.setPermission(contributeLogic, contributeLogic.claim.selector, address(rewardRouter));
        dictator.setPermission(rewardLogic, rewardLogic.claim.selector, address(rewardRouter));
        dictator.setPermission(rewardLogic, rewardLogic.userDistribute.selector, address(rewardRouter));
        dictator.setPermission(rewardLogic, rewardLogic.distribute.selector, address(rewardRouter));
        dictator.setPermission(veLogic, veLogic.lock.selector, address(rewardRouter));
        dictator.setPermission(veLogic, veLogic.vest.selector, address(rewardRouter));
        dictator.setPermission(veLogic, veLogic.claim.selector, address(rewardRouter));

        // store settings setup
        dictator.setPermission(contributeLogic, contributeLogic.setBuybackQuote.selector, address(users.owner));
        contributeLogic.setBuybackQuote(wnt, 100e18);
        contributeLogic.setBuybackQuote(usdc, 100e18);

        // permissions used for testing
        vm.startPrank(users.owner);

        wnt.approve(address(router), type(uint).max - 1);
        usdc.approve(address(router), type(uint).max - 1);
        puppetToken.approve(address(router), type(uint).max - 1);
        dictator.setAccess(contributeStore, users.owner);
    }

    function testInitalContributionDelayLock() public {
        contribute(usdc, users.alice, 100e6);
        buyback(usdc, 100e6);
        vm.startPrank(users.alice);
        uint claimedAmount = rewardRouter.claimContribution(claimableTokenList, users.alice, 100e18);

        uint contributionAmount = contributeStore.getBuybackQuote(usdc);

        skip(1000);

        puppetToken.approve(address(router), type(uint).max - 1);
        rewardRouter.lock(claimedAmount, MAXTIME);

        (uint distributionTimeframe,) = rewardLogic.config();
        skip(distributionTimeframe / 2);
        contributeLock(wnt, users.bob, MAXTIME, 1e18);
        skip(distributionTimeframe + 1);
        // assertEq(rewardLogic.getClaimable(users.bob) + rewardLogic.getClaimable(users.alice), contributionAmount *
        // 2);
        claimAssert(users.bob, 75e18);
        claimAssert(users.alice, 125e18);
    }

    function testBuybackDistribution() public {
        uint contributionAmount = 100e6; // 100 USDC
        uint quote = contributeStore.getBuybackQuote(usdc);

        contribute(usdc, users.bob, 20e6);
        contribute(usdc, users.yossi, 80e6);

        // Alice selles her PUPPET tokens for the revenue in WNT tokens
        vm.startPrank(users.alice);
        _dealERC20(address(puppetToken), users.alice, quote);
        puppetToken.approve(address(router), type(uint).max - 1);
        vm.expectRevert();
        rewardRouter.buyback(usdc, users.alice, contributionAmount + 1);
        rewardRouter.buyback(usdc, users.alice, contributionAmount);
        vm.expectRevert();
        rewardRouter.buyback(usdc, users.alice, contributionAmount);

        assertEq(
            usdc.balanceOf(users.alice),
            contributionAmount,
            "Other token balance should be reduced by the buyback amount"
        );

        assertEq(contributeLogic.getClaimable(claimableTokenList, users.bob), 20e18);
        assertEq(contributeLogic.getClaimable(claimableTokenList, users.yossi), 80e18);

        contribute(usdc, users.bob, 80e6);
        contribute(usdc, address(0), 20e6);

        vm.startPrank(users.alice);
        _dealERC20(address(puppetToken), users.alice, quote);
        rewardRouter.buyback(usdc, users.alice, contributionAmount);

        // rewardRouter.updateCursor(usdc, users.yossi);

        assertEq(contributeLogic.getClaimable(claimableTokenList, users.yossi), 80e18);
        assertEq(contributeLogic.getClaimable(claimableTokenList, users.bob), 100e18);

        contribute(usdc, address(0), 123e6);
        vm.startPrank(users.alice);
        _dealERC20(address(puppetToken), users.alice, quote);
        rewardRouter.buyback(usdc, users.alice, 50e6);

        // possible case where contribution is lower in market value than the buyback amount
        // this would result in premium value rewards for the contributors
        contribute(usdc, users.yossi, 5e6);
        contribute(usdc, users.yossi, 5e6);
        contribute(usdc, users.owner, 40e6);

        vm.startPrank(users.alice);
        _dealERC20(address(puppetToken), users.alice, quote);
        rewardRouter.buyback(usdc, users.alice, 50e6);

        assertEq(contributeLogic.getClaimable(claimableTokenList, users.yossi), 100e18);
    }

    function testLockRewards() public {
        (uint distributionTimeframe,) = rewardLogic.config();

        contributeLock(wnt, users.alice, MAXTIME, 1e18);
        skip(distributionTimeframe / 2);

        claimAssert(users.alice, 50e18);
        assertEq(rewardLogic.getClaimable(users.alice), 0);

        contributeLock(wnt, users.bob, MAXTIME, 1e18);
        skip(distributionTimeframe);

        claimAssert(users.alice, 75e18);
        claimAssert(users.bob, 75e18);

        assertEq(puppetToken.balanceOf(users.alice), 125e18);
        assertEq(puppetToken.balanceOf(users.bob), 75e18);
    }

    function testLockRewardsDifferentAmounts() public {
        (uint distributionTimeframe,) = rewardLogic.config();

        // Lock different amounts
        contribute(wnt, users.alice, 1e18);
        contribute(wnt, users.bob, 2e18);
        contribute(wnt, users.yossi, 1e18);

        // buyback quote
        uint quote = contributeStore.getBuybackQuote(wnt);

        buyback(wnt, 0.1e18);

        skip(distributionTimeframe);

        // Expect Bob to have twice the rewards of Alice
        uint aliceRewards = contributeLogic.getClaimable(claimableTokenList, users.alice);
        uint bobRewards = contributeLogic.getClaimable(claimableTokenList, users.bob);
        uint yossiRewards = contributeLogic.getClaimable(claimableTokenList, users.yossi);
        assertEq(bobRewards, aliceRewards * 2, "Bob should have twice the rewards of Alice");
        assertEq(bobRewards, yossiRewards * 2, "Bob should have twice the rewards of Yossi");
        assertEq(bobRewards, aliceRewards + yossiRewards, "Bob should have half of total rewards");
    }

    function testLockRewardsAfterUnlock() public {
        (uint distributionTimeframe,) = rewardLogic.config();

        contributeLock(wnt, users.alice, MAXTIME, 1e18);
        skip(distributionTimeframe);

        // Lock expires
        skip(MAXTIME);

        // Claim rewards after lock expired
        uint rewardsAfterUnlock = rewardLogic.getClaimable(users.alice);
        claimAssert(users.alice, rewardsAfterUnlock);
        assertEq(rewardLogic.getClaimable(users.alice), 0, "Alice should have claimed all rewards after lock expired");
    }

    function testLockRewardsWithRewardPerTokenCalculation() public {
        (uint distributionTimeframe,) = rewardLogic.config();

        contributeLock(wnt, users.alice, MAXTIME, 1e18);
        contributeLock(wnt, users.bob, MAXTIME, 1e18);
        contributeLock(wnt, users.bob, MAXTIME, 1e18);

        skip(distributionTimeframe);

        uint aliceRewards = rewardLogic.getClaimable(users.alice);
        uint bobRewards = rewardLogic.getClaimable(users.bob);
        assertEq(bobRewards, aliceRewards * 2, "Bob should have twice the rewards of Alice");
    }

    function testLockRewardsAtIntervals() public {
        (uint distributionTimeframe,) = rewardLogic.config();

        uint initialLockAmount = 1e18;
        uint quote = contributeStore.getBuybackQuote(wnt);

        contributeLock(wnt, users.alice, MAXTIME, initialLockAmount);

        // Claim rewards at different intervals
        skip(distributionTimeframe / 4);
        assertEq(rewardLogic.getClaimable(users.alice), 25e18);
        skip(distributionTimeframe / 4);
        assertEq(rewardLogic.getClaimable(users.alice), 50e18);
        skip(distributionTimeframe / 2);
        assertEq(rewardLogic.getClaimable(users.alice), 100e18);

        claimAssert(users.alice, 100e18);

        assertEq(puppetToken.balanceOf(users.alice), 100e18, "Charlie should have claimed 100e18 in total");
    }

    function buyback(IERC20 token, uint contribution) public {
        uint quote = contributeStore.getBuybackQuote(token);
        _dealERC20(address(token), users.owner, quote);
        rewardRouter.buyback(token, users.owner, contribution);
    }

    function contribute(IERC20 token, address user, uint amount) public {
        vm.startPrank(users.owner);
        _dealERC20(address(token), users.owner, amount);
        contributeStore.contribute(token, users.owner, user, amount);
    }

    function contributeLock(IERC20 token, address user, uint lockDuration, uint contribution) public returns (uint) {
        contribute(token, user, contribution);
        buyback(wnt, contribution);

        uint contributionQuote = contributeStore.getBuybackQuote(token);

        vm.startPrank(user);

        uint amount = rewardRouter.claimContribution(claimableTokenList, user, contributionQuote);

        puppetToken.approve(address(router), type(uint).max - 1);
        rewardRouter.lock(amount, lockDuration);

        return amount;
    }

    function claimAssert(address user, uint amount) public returns (uint) {
        vm.startPrank(user);

        uint claimable = rewardLogic.getClaimable(user);
        rewardRouter.claimEmission(user, amount);
        uint deltaBalance = claimable - rewardLogic.getClaimable(user);

        assertEq(deltaBalance, amount, "Claimed amount should be equal to the expected amount");

        return deltaBalance;
    }

    function fromPriceToSqrt(uint usdcPerWeth) public pure returns (uint160) {
        return uint160(Math.sqrt(usdcPerWeth * 1e12) << 96) / 1e12 + 1;
    }
}
