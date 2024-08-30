// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {RewardRouter} from "src/RewardRouter.sol";
import {ContributeLogic} from "src/tokenomics/ContributeLogic.sol";
import {PuppetToken} from "src/tokenomics/PuppetToken.sol";
import {RewardLogic} from "src/tokenomics/RewardLogic.sol";
import {MAXTIME, VotingEscrowLogic} from "src/tokenomics/VotingEscrowLogic.sol";
import {ContributeStore} from "src/tokenomics/store/ContributeStore.sol";
import {RewardStore} from "src/tokenomics/store/RewardStore.sol";
import {VotingEscrowStore} from "src/tokenomics/store/VotingEscrowStore.sol";
import {Precision} from "src/utils/Precision.sol";
import {BasicSetup} from "test/base/BasicSetup.t.sol";
import {MockWeightedPoolVault} from "test/mocks/MockWeightedPoolVault.sol";

contract RewardRouterTest is BasicSetup {
    VotingEscrowLogic veLogic;
    MockWeightedPoolVault primaryVaultPool;
    RewardStore rewardStore;
    ContributeStore contributeStore;
    RewardLogic rewardLogic;
    ContributeLogic contributeLogic;
    VotingEscrowStore veStore;
    RewardRouter rewardRouter;

    function setUp() public override {
        vm.warp(1716671477);

        super.setUp();

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

        allowNextLoggerAccess();
        contributeLogic = new ContributeLogic(
            dictator, eventEmitter, puppetToken, contributeStore, ContributeLogic.Config({baselineEmissionRate: 0.5e30})
        );

        allowNextLoggerAccess();
        rewardLogic = new RewardLogic(
            dictator,
            eventEmitter,
            puppetToken,
            vPuppetToken,
            rewardStore,
            RewardLogic.Config({distributionStore: contributeStore, distributionTimeframe: 1 weeks})
        );

        allowNextLoggerAccess();
        rewardRouter = new RewardRouter(
            dictator,
            eventEmitter,
            RewardRouter.Config({contributeLogic: contributeLogic, rewardLogic: rewardLogic, veLogic: veLogic})
        );

        dictator.setPermission(puppetToken, puppetToken.mint.selector, address(contributeLogic));
        dictator.setPermission(puppetToken, puppetToken.mint.selector, address(veLogic));

        dictator.setAccess(contributeStore, address(contributeLogic));
        dictator.setAccess(rewardStore, address(rewardLogic));
        dictator.setAccess(veStore, address(veLogic));
        dictator.setAccess(contributeStore, address(rewardStore));

        dictator.setPermission(router, router.transfer.selector, address(contributeStore));
        dictator.setPermission(router, router.transfer.selector, address(rewardStore));
        dictator.setPermission(router, router.transfer.selector, address(veStore));

        dictator.setPermission(contributeLogic, contributeLogic.buyback.selector, address(rewardRouter));
        dictator.setPermission(contributeLogic, contributeLogic.claim.selector, address(rewardRouter));
        dictator.setPermission(contributeLogic, contributeLogic.updateCursor.selector, address(rewardRouter));
        dictator.setPermission(rewardLogic, rewardLogic.claim.selector, address(rewardRouter));
        dictator.setPermission(rewardLogic, rewardLogic.userDistribute.selector, address(rewardRouter));
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

    // bob gets the distributed reward in Puppet based on the contribution and `baselineEmissionRate`
    // uint baselineEmissionRate = contributeLogic.config();
    // rewardRouter.updateUserTokenRewardState(usdc, users.bob);
    // rewardRouter.claimContribution(users.bob, 20e18);
    // assertEq(
    //     puppetToken.balanceOf(users.bob),
    //     Precision.applyFactor(baselineEmissionRate, 20e18),
    //     "Bob should receive 500 Puppet tokens based on 50% baseline emission rate"
    // );
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
        rewardRouter.updateCursor(usdc, users.bob);
        rewardRouter.updateCursor(usdc, users.yossi);

        assertEq(
            usdc.balanceOf(users.alice),
            contributionAmount,
            "Other token balance should be reduced by the buyback amount"
        );

        assertEq(contributeLogic.getClaimable(users.bob), 20e18);
        assertEq(contributeLogic.getClaimable(users.yossi), 80e18);

        contribute(usdc, users.bob, 80e6);
        contribute(usdc, address(0), 20e6);

        vm.startPrank(users.alice);
        _dealERC20(address(puppetToken), users.alice, quote);
        rewardRouter.buyback(usdc, users.alice, contributionAmount);

        rewardRouter.updateCursor(usdc, users.bob);
        // rewardRouter.updateCursor(usdc, users.yossi);

        assertEq(contributeLogic.getClaimable(users.yossi), 80e18);
        assertEq(contributeLogic.getClaimable(users.bob), 100e18);

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

        rewardRouter.updateCursor(usdc, users.yossi);

        assertEq(contributeLogic.getClaimable(users.yossi), 100e18);
    }

    // function testLockOption() public {
    //     (uint distributionTimeframe,) = rewardLogic.config();

    //     lock(wnt, users.yossi, MAXTIME, 1e18);
    //     skip(distributionTimeframe / 2);
    //     assertApproxEqAbs(rewardLogic.getClaimable(users.yossi), 50e18, 0.01e18);

    //     lock(wnt, users.alice, MAXTIME, 1e18);

    //     // lock(wnt, users.alice, MAXTIME, 1e18);
    //     assertApproxEqAbs(rewardLogic.getClaimable(users.yossi), 50e18, 0.01e18);

    //     // skip(distributionTimeframe);

    //     // assertApproxEqAbs(rewardLogic.getClaimable(users.yossi), 50e18, 0.01e18);

    //     // // rewardLogic.claim(users.yossi)

    //     // rewardRouter.claimEmission(users.yossi, 50e18);

    //     // assertApproxEqAbs(, 50e18, 0.01e18);

    //     // skip(distributionTimeframe);

    //     // rewardLogic.getClaimable(users.yossi);
    //     // rewardLogic.getClaimable(users.alice);

    //     // assertApproxEqAbs(rewardLogic.getClaimable(users.yossi), 100e18, 0.1e18);
    //     // assertApproxEqAbs(rewardLogic.getClaimable(users.alice), 50e18, 0.1e18);

    //     // assertApproxEqAbs(
    //     //     rewardLogic.getClaimableEmission(wnt, users.alice) + rewardLogic.getClaimableEmission(wnt,
    //     // users.yossi),
    //     //     2e18,
    //     //     0.001e18
    //     // );
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

    function buybackEth(uint amount) public {
        uint ethPerPuppet = 0.001e18;
        uint thresholdAmount = contributeStore.getBuybackQuote(wnt);

        uint revenue = rewardStore.getTokenBalance(wnt);

        if ((revenue / ethPerPuppet) >= thresholdAmount) {
            rewardRouter.buyback(wnt, users.owner, amount);
        }
    }

    function contribute(IERC20 token, address user, uint amount) public {
        vm.startPrank(users.owner);
        _dealERC20(address(token), users.owner, amount);
        contributeStore.contribute(token, users.owner, user, amount);

        // skip block
        vm.roll(block.number + 1);
    }

    function lock(IERC20 token, address user, uint lockDuration, uint contribution) public returns (uint) {
        contribute(token, user, contribution);
        uint quote = contributeStore.getBuybackQuote(token);
        _dealERC20(address(token), users.owner, quote);
        rewardRouter.buyback(token, users.owner, contribution);
        vm.startPrank(user);
        puppetToken.approve(address(router), type(uint).max - 1);
        // rewardRouter.updateUserTokenRewardState(token, user);
        uint amount = rewardRouter.claimContribution(user, quote);

        rewardRouter.lock(amount, lockDuration);

        return amount;
    }

    // function exit(IERC20 token, address user, uint cugarAmount) public returns (uint) {
    //     // uint claimableInToken = router.exitOption(token, cugarAmount, user);

    //     return 0;
    // }

    // function claim(IERC20 token, address user, uint amount) public returns (uint) {
    //     vm.startPrank(user);

    //     return tokenomicsRouter.claimEmission(token, user, amount);
    // }

    function fromPriceToSqrt(uint usdcPerWeth) public pure returns (uint160) {
        return uint160(Math.sqrt(usdcPerWeth * 1e12) << 96) / 1e12 + 1;
    }
}
