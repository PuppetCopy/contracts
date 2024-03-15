// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

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
import {RewardStore} from "src/tokenomics/store/RewardStore.sol";

import {BasicSetup} from "test/base/BasicSetup.t.sol";
import {MockWeightedPoolVault} from "test/mocks/MockWeightedPoolVault.sol";
import {MockUniswapV3Pool} from "test/mocks/MockUniswapV3Pool.sol";

contract RewardRouterTest is BasicSetup {
    MockWeightedPoolVault vault;
    OracleLogic oracleLogic;
    OracleStore oracleStore;
    RewardRouter rewardRouter;
    RewardStore rewardStore;
    VotingEscrow votingEscrow;
    RewardLogic rewardLogic;
    VeRevenueDistributor revenueDistributor;
    IERC20 revenueToken;
    IUniswapV3Pool[] wntUsdPoolList;

    uint8 constant ORACLE_LOGIC_ROLE = 2;
    uint8 constant REWARD_LOGIC_ROLE = 3;
    uint8 constant VESTING_ROLE = 4;
    uint8 constant REWARD_DISTRIBUTOR_ROLE = 5;

    uint public lockRate = 6000;
    uint public exitRate = 3000;
    uint public treasuryLockRate = 667;
    uint public treasuryExitRate = 333;

    function setUp() public override {
        super.setUp();

        wntUsdPoolList = new MockUniswapV3Pool[](3);

        wntUsdPoolList[0] = new MockUniswapV3Pool(fromPriceToSqrt(100));
        wntUsdPoolList[1] = new MockUniswapV3Pool(fromPriceToSqrt(100));
        wntUsdPoolList[2] = new MockUniswapV3Pool(fromPriceToSqrt(100));

        revenueToken = IERC20(address(deployMockERC20("St4bl3 Muppet Koin", "sMPT", 6)));

        vault = new MockWeightedPoolVault();
        vault.initPool(address(puppetToken), address(address(0x0b)), 2000e18, 80e18);

        oracleLogic = new OracleLogic(dictator);
        dictator.setRoleCapability(ORACLE_LOGIC_ROLE, address(oracleLogic), oracleLogic.syncTokenPrice.selector, true);

        oracleStore = new OracleStore(dictator, address(oracleLogic), oracleLogic.getTokenPriceInUsd(wntUsdPoolList, vault, 0, 0), 1 days);

        rewardLogic = new RewardLogic(dictator);
        dictator.setRoleCapability(REWARD_LOGIC_ROLE, address(rewardLogic), rewardLogic.lock.selector, true);
        dictator.setRoleCapability(REWARD_LOGIC_ROLE, address(rewardLogic), rewardLogic.exit.selector, true);
        dictator.setRoleCapability(REWARD_LOGIC_ROLE, address(rewardLogic), rewardLogic.claim.selector, true);
        dictator.setRoleCapability(REWARD_LOGIC_ROLE, address(rewardLogic), rewardLogic.setUserGeneratedRevenue.selector, true);

        rewardStore = new RewardStore(dictator, address(rewardLogic));

        votingEscrow = new VotingEscrow(dictator, router, puppetToken);
        dictator.setRoleCapability(VESTING_ROLE, address(votingEscrow), votingEscrow.lock.selector, true);
        dictator.setRoleCapability(VESTING_ROLE, address(votingEscrow), votingEscrow.depositFor.selector, true);
        dictator.setRoleCapability(VESTING_ROLE, address(votingEscrow), votingEscrow.withdraw.selector, true);

        revenueDistributor = new VeRevenueDistributor(dictator, votingEscrow, router, 1 weeks);
        dictator.setRoleCapability(REWARD_DISTRIBUTOR_ROLE, address(revenueDistributor), revenueDistributor.claim.selector, true);
        dictator.setRoleCapability(REWARD_DISTRIBUTOR_ROLE, address(revenueDistributor), revenueDistributor.depositToken.selector, true);

        rewardRouter = new RewardRouter(
            RewardRouter.RewardRouterParams({
                dictator: dictator,
                puppetToken: puppetToken,
                lp: vault,
                router: router,
                oracleStore: oracleStore,
                votingEscrow: votingEscrow,
                wnt: wnt
            }),
            RewardRouter.RewardRouterConfig({
                revenueDistributor: revenueDistributor,
                wntUsdPoolList: wntUsdPoolList,
                wntUsdTwapInterval: 0,
                rewardStore: rewardStore,
                rewardLogic: rewardLogic,
                oracleLogic: oracleLogic,
                dao: dictator.owner(),
                revenueToken: revenueToken,
                poolId: keccak256(abi.encode("POOL", "DEFAULT")),
                lockRate: lockRate,
                exitRate: exitRate,
                treasuryLockRate: treasuryLockRate,
                treasuryExitRate: treasuryExitRate
            })
        );

        dictator.setUserRole(address(votingEscrow), TOKEN_ROUTER_ROLE, true);
        dictator.setUserRole(address(revenueDistributor), TOKEN_ROUTER_ROLE, true);

        dictator.setUserRole(address(users.owner), REWARD_LOGIC_ROLE, true);
        dictator.setUserRole(address(users.owner), REWARD_DISTRIBUTOR_ROLE, true);

        dictator.setUserRole(address(rewardLogic), PUPPET_MINTER_ROLE, true);
        dictator.setUserRole(address(rewardLogic), VESTING_ROLE, true);
        dictator.setUserRole(address(rewardLogic), REWARD_DISTRIBUTOR_ROLE, true);
        dictator.setUserRole(address(rewardLogic), ORACLE_LOGIC_ROLE, true);

        dictator.setUserRole(address(rewardRouter), REWARD_LOGIC_ROLE, true);
        dictator.setUserRole(address(rewardRouter), VESTING_ROLE, true);
    }

    function testOption() public {
        assertEq(oracleLogic.getMedianWntPriceInUsd(wntUsdPoolList, 0), 100e6, "wnt at $100");

        vm.warp(2 weeks);

        puppetToken.transfer(address(0x123), puppetToken.balanceOf(users.owner));
        vm.expectRevert(RewardLogic.RewardLogic__NoClaimableAmount.selector);
        rewardRouter.lock(getMaxTime(), 100e6);

        vm.expectRevert(RewardLogic.RewardLogic__UnacceptableTokenPrice.selector);
        rewardRouter.lock(getMaxTime(), 9e5);

        generateUserRevenue(users.alice, 100e6);
        vm.expectRevert(VotingEscrow.VotingEscrow__InvalidLockValue.selector);
        rewardRouter.lock(0, 1e6);

        assertEq(rewardLogic.getAccountGeneratedRevenue(rewardStore, users.alice).amountInUsd, 100e6);

        rewardRouter.lock(getMaxTime(), 1e6);
        uint daoClaimableAmount1 = rewardLogic.getClaimableAmount(treasuryLockRate, 100e18);
        assertEq(puppetToken.balanceOf(dictator.owner()), daoClaimableAmount1);
        assertAlmostEq(votingEscrow.balanceOf(users.alice), rewardLogic.getClaimableAmount(lockRate, 100e18), 10e17);

        vm.expectRevert(RewardLogic.RewardLogic__NoClaimableAmount.selector);
        rewardRouter.lock(getMaxTime(), 1e6);

        assertEq(rewardLogic.getAccountGeneratedRevenue(rewardStore, users.alice).amountInUsd, 0);

        generateUserRevenue(users.alice, 100e6);
        rewardRouter.exit(1e6);
        assertEq(puppetToken.balanceOf(users.alice), 30e18);
        assertEq(puppetToken.balanceOf(dictator.owner()), rewardLogic.getClaimableAmount(treasuryExitRate, 100e18) + daoClaimableAmount1);

        vm.expectRevert(RewardLogic.RewardLogic__NoClaimableAmount.selector);
        rewardRouter.exit(1e6);

        generateUserRevenue(users.alice, 100e6);
        assertEq(rewardLogic.getAccountGeneratedRevenue(rewardStore, users.alice).amountInUsd, 100e6);
        rewardRouter.lock(0, 1e6);
        assertAlmostEq(votingEscrow.balanceOf(users.alice), rewardLogic.getClaimableAmount(lockRate, 200e18), 10e17);

        generateUserRevenue(users.bob, 100e6);
        assertEq(rewardLogic.getAccountGeneratedRevenue(rewardStore, users.bob).amountInUsd, 100e6);
        rewardRouter.lock(getMaxTime(), 1e6);
        assertAlmostEq(votingEscrow.balanceOf(users.bob), rewardLogic.getClaimableAmount(lockRate, 100e18), 10e17);

        generateUserRevenue(users.yossi, 100e6);
        assertEq(rewardLogic.getAccountGeneratedRevenue(rewardStore, users.yossi).amountInUsd, 100e6);
        rewardRouter.lock(getMaxTime() / 2, 1e6);
        assertAlmostEq(votingEscrow.balanceOf(users.yossi), rewardLogic.getClaimableAmount(lockRate, 100e18 / 2) / 2, 10e17);
        assertEq(votingEscrow.lockedAmount(users.yossi), rewardLogic.getClaimableAmount(lockRate, 100e18) / 2);
        assertEq(rewardLogic.getRewardTimeMultiplier(votingEscrow, users.yossi, getMaxTime() / 2), 5000);

        // vm.warp(3 weeks);

        depositRevenue(500e6);
        assertEq(revenueDistributor.getTokensDistributedInWeek(revenueToken, 3 weeks), 500e6);

        revenueDistributor.getUserTokenTimeCursor(users.alice, revenueToken);
        revenueDistributor.getTotalSupplyAtTimestamp(3 weeks);
        revenueDistributor.getTimeCursor();
        revenueDistributor.getClaimableToken(revenueToken, users.alice);
        assertGt(rewardRouter.claim(users.bob), 0, "Alice has no claimable revenue");

        // Users claim their revenue
        // uint aliceRevenueBefore = revenueInToken.balanceOf(users.alice);
        // uint bobRevenueBefore = revenueInToken.balanceOf(users.bob);
        // revenueDistributor.getUserTimeCursor(users.alice);

        // votingEscrow.getUserPointHistory(users.alice, revenueDistributor.userEpochOf(users.alice));
        // uint _lastTokenTime = (revenueDistributor.lastTokenTime() / 1 weeks) * 1 weeks;

        // emit LogUint256(_lastTokenTime);

        votingEscrow.totalSupply(block.timestamp);

        skip(1 weeks);

        // generateUserRevenue(users.yossi, 100e6);
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
        revenueToken.approve(address(router), amount);
        revenueDistributor.depositToken(revenueToken, amount);
        revenueToken.balanceOf(address(revenueDistributor));
    }

    function generateUserRevenue(address user, uint amount) public returns (uint) {
        vm.startPrank(users.owner);

        _dealERC20(address(revenueToken), users.owner, amount);
        rewardLogic.setUserGeneratedRevenue(
            rewardStore, user, RewardStore.UserGeneratedRevenue({amountInToken: amount, amountInUsd: amount, token: revenueToken})
        );

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
