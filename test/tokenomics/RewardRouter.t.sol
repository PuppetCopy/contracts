// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/interfaces/IUniswapV3Pool.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {RewardRouter} from "src/RewardRouter.sol";
import {OracleLogic} from "src/tokenomics/OracleLogic.sol";
import {OracleStore} from "src/tokenomics/store/OracleStore.sol";
import {PuppetToken} from "src/tokenomics/PuppetToken.sol";
import {VotingEscrow, MAXTIME} from "src/tokenomics/VotingEscrow.sol";
import {RewardLogic} from "src/tokenomics/RewardLogic.sol";
import {VeRevenueDistributor} from "src/tokenomics/VeRevenueDistributor.sol";

import {UserGeneratedRevenueStore} from "src/shared/store/UserGeneratedRevenueStore.sol";
import {UserGeneratedRevenue} from "src/shared/UserGeneratedRevenue.sol";

import {PositionUtils} from "src/position/util/PositionUtils.sol";

import {IWNT} from "src/utils/interfaces/IWNT.sol";

import {BasicSetup} from "test/base/BasicSetup.t.sol";
import {MockWeightedPoolVault} from "test/mocks/MockWeightedPoolVault.sol";
import {MockUniswapV3Pool} from "test/mocks/MockUniswapV3Pool.sol";

contract RewardRouterTest is BasicSetup {
    MockWeightedPoolVault vault;
    OracleStore usdPerWntStore;
    OracleStore puppetPerWntStore;
    RewardRouter rewardRouter;
    UserGeneratedRevenue userGeneratedRevenue;
    UserGeneratedRevenueStore userGeneratedRevenueStore;
    VotingEscrow votingEscrow;
    VeRevenueDistributor revenueDistributor;
    IERC20 usdcTokenRevenue;
    IWNT wntTokenRevenue;
    IUniswapV3Pool[] wntUsdPoolList;

    OracleLogic.CallConfig callOracleConfig;

    uint8 constant REVENUE_OPERATOR = 2;
    uint8 constant REWARD_LOGIC_ROLE = 3;
    uint8 constant VESTING_ROLE = 4;
    uint8 constant REWARD_DISTRIBUTOR_ROLE = 5;

    uint public lockRate = 6000;
    uint public exitRate = 3000;

    function setUp() public override {
        super.setUp();

        wntUsdPoolList = new MockUniswapV3Pool[](3);

        wntUsdPoolList[0] = new MockUniswapV3Pool(fromPriceToSqrt(100));
        wntUsdPoolList[1] = new MockUniswapV3Pool(fromPriceToSqrt(100));
        wntUsdPoolList[2] = new MockUniswapV3Pool(fromPriceToSqrt(100));

        usdcTokenRevenue = IERC20(address(deployMockERC20("St4bl3", "sMPT", 6)));
        address rewardRouterAddress = computeCreateAddress(owner, vm.getNonce(owner) + 7);

        vault = new MockWeightedPoolVault();
        vault.initPool(address(puppetToken), address(address(0x0b)), 20e18, 80e18);

        usdPerWntStore = new OracleStore(dictator, rewardRouterAddress, 100e30);
        puppetPerWntStore = new OracleStore(dictator, rewardRouterAddress, 1e18);

        callOracleConfig = OracleLogic.CallConfig({
            wntUsdSourceList: wntUsdPoolList,
            vault: vault,
            // usdPerWntStore: usdPerWntStore,
            tokenPerWntStore: puppetPerWntStore,
            poolId: keccak256("TEST_POOL_ID"),
            twapInterval: 0,
            updateInterval: 1 days
        });

        userGeneratedRevenue = new UserGeneratedRevenue(dictator);
        userGeneratedRevenueStore = new UserGeneratedRevenueStore(dictator, address(userGeneratedRevenue));
        dictator.setRoleCapability(REVENUE_OPERATOR, address(userGeneratedRevenue), userGeneratedRevenue.claimUserGeneratedRevenueList.selector, true);
        dictator.setRoleCapability(REVENUE_OPERATOR, address(userGeneratedRevenue), userGeneratedRevenue.claimUserGeneratedRevenueList.selector, true);

        votingEscrow = new VotingEscrow(dictator, router, puppetToken);
        dictator.setRoleCapability(VESTING_ROLE, address(votingEscrow), votingEscrow.lock.selector, true);
        dictator.setRoleCapability(VESTING_ROLE, address(votingEscrow), votingEscrow.depositFor.selector, true);
        dictator.setRoleCapability(VESTING_ROLE, address(votingEscrow), votingEscrow.withdraw.selector, true);

        revenueDistributor = new VeRevenueDistributor(dictator, votingEscrow, router, 1 weeks);
        dictator.setRoleCapability(REWARD_DISTRIBUTOR_ROLE, address(revenueDistributor), revenueDistributor.claim.selector, true);
        dictator.setRoleCapability(REWARD_DISTRIBUTOR_ROLE, address(revenueDistributor), revenueDistributor.depositToken.selector, true);

        rewardRouter = new RewardRouter(
            dictator,
            wnt,
            router,
            votingEscrow,
            revenueDistributor,
            callOracleConfig,
            RewardLogic.CallLockConfig({
                router: router,
                votingEscrow: votingEscrow,
                userGeneratedRevenueStore: userGeneratedRevenueStore,
                userGeneratedRevenue: userGeneratedRevenue,
                revenueDistributor: revenueDistributor,
                puppetToken: puppetToken,
                rate: 6000
            }),
            RewardLogic.CallExitConfig({
                userGeneratedRevenueStore: userGeneratedRevenueStore,
                userGeneratedRevenue: userGeneratedRevenue,
                revenueDistributor: revenueDistributor,
                puppetToken: puppetToken,
                rate: 3000
            })
        );

        dictator.setUserRole(address(votingEscrow), TOKEN_ROUTER_ROLE, true);
        dictator.setUserRole(address(revenueDistributor), TOKEN_ROUTER_ROLE, true);

        dictator.setUserRole(address(rewardRouter), PUPPET_MINTER_ROLE, true);
        dictator.setUserRole(address(rewardRouter), REWARD_LOGIC_ROLE, true);
        dictator.setUserRole(address(rewardRouter), VESTING_ROLE, true);
        dictator.setUserRole(address(userGeneratedRevenue), REVENUE_OPERATOR, true);

        dictator.setUserRole(address(rewardRouter), REVENUE_OPERATOR, true);
        dictator.setUserRole(owner, REVENUE_OPERATOR, true);
    }

    function testOption() public {
        // assertAlmostEq(rewardRouter.getMedianWntPriceInUsd(callOracleConfig), 100e30, 0.5e30, "wnt at $100");

        vm.warp(2 weeks);

        // puppetToken.transfer(address(0x123), puppetToken.balanceOf(users.owner));
        // vm.expectRevert(RewardLogic.RewardLogic__NoClaimableAmount.selector);
        // rewardRouter.lock(100.1e30, getMaxTime());

        // vm.expectRevert();
        // rewardRouter.lock(0.8e30, getMaxTime());

        // generateUserRevenueInUsdc(users.alice, 100e30);
        // vm.expectRevert(VotingEscrow.VotingEscrow__InvalidLockValue.selector);
        // rewardRouter.lock(100e30, 0);

        // assertEq(userGeneratedRevenue.getUserGeneratedRevenue(userGeneratedRevenueStore, users.alice).amountInUsd, 100e30);

        // rewardRouter.lock(100.1e30, getMaxTime());
        // assertAlmostEq(votingEscrow.balanceOf(users.alice), RewardLogic.getClaimableAmount(lockRate, 100e18), 10e17);

        // vm.expectRevert(RewardLogic.RewardLogic__NoClaimableAmount.selector);
        // rewardRouter.lock(100.1e30, getMaxTime());

        // assertEq(userGeneratedRevenue.getUserGeneratedRevenue(userGeneratedRevenueStore, users.alice).amountInUsd, 0);

        // generateUserRevenue(users.alice, 100e30);
        // rewardRouter.exit(1e30);
        // assertEq(puppetToken.balanceOf(users.alice), 30e18);

        // vm.expectRevert(RewardLogic.RewardLogic__NoClaimableAmount.selector);
        // rewardRouter.exit(1e30);

        // generateUserRevenue(users.alice, 100e30);
        // assertEq(userGeneratedRevenue.getUserGeneratedRevenue(userGeneratedRevenueStore, users.alice).amountInUsd, 100e30);
        // rewardRouter.lock(1e30, 0);
        // assertAlmostEq(votingEscrow.balanceOf(users.alice), RewardLogic.getClaimableAmount(lockRate, 200e18), 10e17);

        // generateUserRevenue(users.bob, 100e30);
        // assertEq(userGeneratedRevenue.getUserGeneratedRevenue(userGeneratedRevenueStore, users.bob).amountInUsd, 100e30);
        // rewardRouter.lock(1e30, getMaxTime());
        // assertAlmostEq(votingEscrow.balanceOf(users.bob), RewardLogic.getClaimableAmount(lockRate, 100e18), 10e17);

        // generateUserRevenue(users.yossi, 100e30);
        // assertEq(userGeneratedRevenue.getUserGeneratedRevenue(userGeneratedRevenueStore, users.yossi).amountInUsd, 100e30);
        // rewardRouter.lock(1e30, getMaxTime() / 2);
        // assertAlmostEq(votingEscrow.balanceOf(users.yossi), RewardLogic.getClaimableAmount(lockRate, 100e18 / 2) / 2, 10e17);
        // assertEq(votingEscrow.lockedAmount(users.yossi), RewardLogic.getClaimableAmount(lockRate, 100e18) / 2);
        // assertEq(RewardLogic.getRewardTimeMultiplier(votingEscrow, users.yossi, getMaxTime() / 2), 5000);

        // // vm.warp(3 weeks);

        // depositRevenue(500e30);
        // assertEq(revenueDistributor.getTokensDistributedInWeek(usdcTokenRevenue, 3 weeks), 500e30);

        // revenueDistributor.getUserTokenTimeCursor(users.alice, usdcTokenRevenue);
        // revenueDistributor.getTotalSupplyAtTimestamp(3 weeks);
        // revenueDistributor.getTimeCursor();
        // revenueDistributor.getClaimableToken(usdcTokenRevenue, users.alice);
        // assertGt(rewardRouter.claim(users.bob), 0, "Alice has no claimable revenue");

        // Users claim their revenue
        // uint aliceRevenueBefore = revenueInToken.balanceOf(users.alice);
        // uint bobRevenueBefore = revenueInToken.balanceOf(users.bob);
        // revenueDistributor.getUserTimeCursor(users.alice);

        // votingEscrow.getUserPointHistory(users.alice, revenueDistributor.userEpochOf(users.alice));
        // uint _lastTokenTime = (revenueDistributor.lastTokenTime() / 1 weeks) * 1 weeks;

        // emit LogUint256(_lastTokenTime);

        // votingEscrow.totalSupply(block.timestamp);

        // skip(1 weeks);

        // generateUserRevenue(users.yossi, 100e30);
        // revenueDistributor.checkpoint();

        // assertGt(rewardRouter.claim(users.alice), 0, "Alice has no claimable revenue");
        // assertGt(rewardRouter.claimRevenue(users.alice), 0, "Alice has no claimable revenue");
        // assertGt(rewardRouter.claimRevenue(users.alice), 0, "Alice has no revenue");
        // rewardRouter.claimRevenue(users.bob);

        // Simulate some time passing and revenue being generated

        // Check that users' revenue has increased correctly
        // uint aliceRevenueAfter = revenueInToken.balanceOf(users.alice);
        // uint bobRevenueAfter = revenueInToken.balanceOf(users.bob);
        // assertGt(aliceRevenueAfter, aliceRevenueBefore, "Alice's revenue did not increase");
        // assertGt(bobRevenueAfter, bobRevenueBefore, "Bob's revenue did not increase");

        // // Check that the distribution was in proportion to their locked amounts
        // assertEq(aliceRevenueAfter - aliceRevenueBefore, bobRevenueAfter - bobRevenueBefore, "Revenue distribution proportion is incorrect");
    }

    function depositRevenue(uint amount) public {
        vm.startPrank(users.owner);
        usdcTokenRevenue.approve(address(router), amount);
        revenueDistributor.depositToken(usdcTokenRevenue, amount);
        usdcTokenRevenue.balanceOf(address(revenueDistributor));
    }

    function generateUserRevenueInUsdc(IERC20 token, address user, uint amount) public returns (uint) {
        vm.startPrank(users.owner);

        _dealERC20(address(usdcTokenRevenue), users.owner, amount);
        // userGeneratedRevenue.setUserGeneratedRevenue(
        //     userGeneratedRevenueStore,
        //     PositionUtils.getUserGeneratedRevenueKey(token, user),
        //     UserGeneratedRevenueStore.Revenue({from: users.owner, amountInToken: amount, amountInUsd: amount, token: token})
        // );

        // skip block
        vm.roll(block.number + 1);
        vm.startPrank(user);

        return amount;
    }

    function getMaxTime() public view returns (uint) {
        return block.timestamp + MAXTIME;
    }

    function fromPriceToSqrt(uint usdcPerWeth) public pure returns (uint160) {
        return uint160(Math.sqrt(usdcPerWeth * 1e12) << 96) / 1e12 + 1;
    }
}
