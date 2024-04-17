// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/interfaces/IUniswapV3Pool.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {RewardRouter} from "src/RewardRouter.sol";
import {OracleStore} from "src/tokenomics/store/OracleStore.sol";
import {PuppetToken} from "src/tokenomics/PuppetToken.sol";
import {VotingEscrow, MAXTIME} from "src/tokenomics/VotingEscrow.sol";
import {RewardLogic} from "src/tokenomics/logic/RewardLogic.sol";
import {VeRevenueDistributor} from "src/tokenomics/VeRevenueDistributor.sol";
import {RevenueDistributor2} from "./../../src/tokenomics/RevenueDistributor2.sol";
import {Oracle} from "src/tokenomics/Oracle.sol";

import {Precision} from "src/utils/Precision.sol";

import {CugarStore} from "src/shared/store/CugarStore.sol";
import {Cugar} from "src/shared/Cugar.sol";

import {PositionUtils} from "src/position/util/PositionUtils.sol";

import {BasicSetup} from "test/base/BasicSetup.t.sol";
import {MockWeightedPoolVault} from "test/mocks/MockWeightedPoolVault.sol";
import {MockUniswapV3Pool} from "test/mocks/MockUniswapV3Pool.sol";

contract RewardRouterTest is BasicSetup {
    MockWeightedPoolVault primaryVaultPool;
    OracleStore oracleStore;
    RewardRouter rewardRouter;
    Oracle oracle;
    Cugar cugar;
    CugarStore cugarStore;
    VotingEscrow votingEscrow;
    RevenueDistributor2 revenueDistributor;
    IUniswapV3Pool[] wntUsdPoolList;

    Oracle.CallConfig callOracleConfig;

    uint8 constant SET_ORACLE_PRICE_ROLE = 3;
    uint8 constant CLAIM_AND_DISTRIBUTE_CUGAR_ROLE = 4;
    uint8 constant INCREASE_CUGAR_ROLE = 5;
    uint8 constant DISTRIBUTE_CUGAR_ROLE = 6;
    uint8 constant VEST_ROLE = 8;
    uint8 constant REWARD_DISTRIBUTOR_ROLE = 9;
    uint8 constant DEPOSIT_TOKEN_FROM_ROLE = 10;

    uint public lockRate = 6000;
    uint public exitRate = 3000;

    IERC20[] revenueInTokenList;

    function setUp() public override {
        super.setUp();

        wntUsdPoolList = new MockUniswapV3Pool[](3);

        wntUsdPoolList[0] = new MockUniswapV3Pool(fromPriceToSqrt(100));
        wntUsdPoolList[1] = new MockUniswapV3Pool(fromPriceToSqrt(100));
        wntUsdPoolList[2] = new MockUniswapV3Pool(fromPriceToSqrt(100));

        revenueInTokenList = new IERC20[](1);
        revenueInTokenList[0] = usdc;

        Oracle.SecondaryPriceConfig[] memory exchangePriceSourceList = new Oracle.SecondaryPriceConfig[](1);
        exchangePriceSourceList[0] = Oracle.SecondaryPriceConfig({enabled: true, sourceList: wntUsdPoolList, twapInterval: 0, sourceTokenDeicmals: 6});

        primaryVaultPool = new MockWeightedPoolVault();
        primaryVaultPool.initPool(address(puppetToken), address(wnt), 20e18, 80e18);

        address rewardRouterAddress = computeCreateAddress(users.owner, vm.getNonce(users.owner) + 1);

        oracleStore = new OracleStore(dictator, rewardRouterAddress, 1e18);
        oracle = new Oracle(
            dictator,
            oracleStore,
            Oracle.CallConfig({primaryPoolToken1: wnt, vault: primaryVaultPool, poolId: 0, updateInterval: 1 days}),
            revenueInTokenList,
            exchangePriceSourceList
        );
        dictator.setRoleCapability(SET_ORACLE_PRICE_ROLE, address(oracle), oracle.setPrimaryPrice.selector, true);

        cugarStore = new CugarStore(dictator, computeCreateAddress(users.owner, vm.getNonce(users.owner) + 1));
        cugar = new Cugar(dictator, Cugar.CallConfig({store: cugarStore}));
        dictator.setRoleCapability(INCREASE_CUGAR_ROLE, address(cugar), cugar.increase.selector, true);
        dictator.setRoleCapability(DISTRIBUTE_CUGAR_ROLE, address(cugar), cugar.distribute.selector, true);
        dictator.setRoleCapability(CLAIM_AND_DISTRIBUTE_CUGAR_ROLE, address(cugar), cugar.distribute.selector, true);

        votingEscrow = new VotingEscrow(dictator, router, puppetToken);
        // votingEscrow.checkpoint();
        dictator.setRoleCapability(VEST_ROLE, address(votingEscrow), votingEscrow.lock.selector, true);
        dictator.setRoleCapability(VEST_ROLE, address(votingEscrow), votingEscrow.withdraw.selector, true);

        revenueDistributor = new RevenueDistributor2(dictator, votingEscrow, router, block.timestamp);
        skip(1 weeks);

        dictator.setRoleCapability(REWARD_DISTRIBUTOR_ROLE, address(revenueDistributor), revenueDistributor.claim.selector, true);
        dictator.setRoleCapability(DEPOSIT_TOKEN_FROM_ROLE, address(revenueDistributor), revenueDistributor.depositTokenFrom.selector, true);

        rewardRouter = new RewardRouter(
            dictator,
            router,
            votingEscrow,
            revenueDistributor,
            RewardRouter.CallConfig({
                lock: RewardLogic.CallLockConfig({
                    router: router,
                    votingEscrow: votingEscrow,
                    oracle: oracle,
                    cugar: cugar,
                    revenueDistributor: revenueDistributor,
                    puppetToken: puppetToken,
                    revenueSource: users.owner,
                    rate: 6000
                }),
                exit: RewardLogic.CallExitConfig({
                    router: router,
                    oracle: oracle,
                    cugar: cugar,
                    revenueDistributor: revenueDistributor,
                    puppetToken: puppetToken,
                    revenueSource: users.owner,
                    rate: 3000
                })
            })
        );

        dictator.setUserRole(address(votingEscrow), TRANSFER_TOKEN_ROLE, true);
        dictator.setUserRole(address(revenueDistributor), TRANSFER_TOKEN_ROLE, true);
        dictator.setUserRole(address(cugar), TRANSFER_TOKEN_ROLE, true);

        dictator.setUserRole(address(rewardRouter), MINT_PUPPET_ROLE, true);
        dictator.setUserRole(address(rewardRouter), VEST_ROLE, true);

        dictator.setUserRole(address(rewardRouter), SET_ORACLE_PRICE_ROLE, true);
        dictator.setUserRole(address(rewardRouter), CLAIM_AND_DISTRIBUTE_CUGAR_ROLE, true);

        dictator.setUserRole(address(cugar), DEPOSIT_TOKEN_FROM_ROLE, true);
        dictator.setUserRole(users.owner, INCREASE_CUGAR_ROLE, true);

        wnt.approve(address(router), type(uint).max - 1);
        revenueInTokenList[0].approve(address(router), type(uint).max - 1);
    }

    function testOption() public {
        assertEq(oracle.getPrimaryPoolPrice(), 1e18, "1-1 pool price with 30 decimals precision");
        assertEq(oracle.getMaxPrice(usdc), 100e6, "100usdc per puppet");

        vm.expectRevert(abi.encodeWithSelector(RewardLogic.RewardLogic__NotEnoughToClaim.selector, 0));
        rewardRouter.lock(wnt, getMaxTime(), 1e18, 200e18);

        generateUserRevenueInWnt(users.alice, 1e18);
        assertEq(rewardRouter.getClaimableAmount(RewardLogic.Choice.LOCK, wnt, users.alice, 1e18), 0.6e18);
        generateUserRevenueInUsdc(users.alice, 100e6);
        assertEq(rewardRouter.getClaimableAmount(RewardLogic.Choice.LOCK, usdc, users.alice, 100e6), 0.6e18);

        vm.expectRevert(Oracle.Oracle__UnavailableSecondaryPrice.selector);
        oracle.getSecondaryPrice(wnt);
        vm.expectRevert(Oracle.Oracle__UnavailableSecondaryPrice.selector);
        oracle.getSecondaryPrice(puppetToken);

        vm.expectRevert(abi.encodeWithSelector(RewardLogic.RewardLogic__UnacceptableTokenPrice.selector, 100e6));
        rewardRouter.lock(usdc, getMaxTime(), 0.9e6, 100e6);

        vm.expectRevert(abi.encodeWithSelector(RewardLogic.RewardLogic__NotEnoughToClaim.selector, 100e6));
        rewardRouter.lock(usdc, getMaxTime(), 100e6, 200e6);
        vm.expectRevert(abi.encodeWithSelector(RewardLogic.RewardLogic__NotEnoughToClaim.selector, 1e18));
        rewardRouter.lock(wnt, getMaxTime(), 1e18, 200e18);

        rewardRouter.lock(wnt, getMaxTime(), 1e18, 1e18);
        assertAlmostEq(votingEscrow.balanceOf(users.alice), Precision.applyBasisPoints(lockRate, 1e18), 5e16);
        rewardRouter.lock(usdc, getMaxTime(), 100e6, 100e6);
        assertAlmostEq(votingEscrow.balanceOf(users.alice), Precision.applyBasisPoints(lockRate, 2e18), 0.01e18);

        vm.expectRevert(abi.encodeWithSelector(RewardLogic.RewardLogic__NotEnoughToClaim.selector, 0));
        rewardRouter.lock(usdc, getMaxTime(), 100e6, 100e6);

        vm.expectRevert(abi.encodeWithSelector(RewardLogic.RewardLogic__NotEnoughToClaim.selector, 0));
        rewardRouter.lock(wnt, getMaxTime(), 1e18, 1e18);

        assertEq(cugar.get(PositionUtils.getCugarKey(wnt, users.alice)), 0);
        assertEq(cugar.get(PositionUtils.getCugarKey(usdc, users.alice)), 0);

        // skip(1 weeks);

        generateUserRevenueInWnt(users.alice, 1e18);
        rewardRouter.exit(wnt, 1e18, 1e18);
        generateUserRevenueInUsdc(users.alice, 100e6);
        rewardRouter.lock(usdc, getMaxTime(), 100e6, 100e6);
        assertEq(puppetToken.balanceOf(users.alice), 0.3e18);

        generateUserRevenueInUsdc(users.bob, 100e6);
        assertEq(rewardRouter.getClaimableAmount(RewardLogic.Choice.LOCK, usdc, users.bob, 100e6), 0.6e18);
        assertEq(rewardRouter.getClaimableAmount(RewardLogic.Choice.EXIT, usdc, users.bob, 100e6), 0.3e18);
        rewardRouter.exit(usdc, 100e6, 100e6);
        assertEq(puppetToken.balanceOf(users.bob), 0.3e18);

        generateUserRevenueInUsdc(users.bob, 100e6);
        assertEq(rewardRouter.getClaimableAmount(RewardLogic.Choice.LOCK, usdc, users.bob, 100e6), 0.6e18);
        rewardRouter.lock(usdc, getMaxTime() / 2, 100e6, 100e6);
        assertAlmostEq(votingEscrow.balanceOf(users.bob), Precision.applyBasisPoints(lockRate, 1e18) / 4, 0.01e18);

        votingEscrow.checkpoint();
        votingEscrow.epoch();

        // revenueDistributor.checkpoint();

        // revenueDistributor.getTokensDistributedInWeek(usdc, 3 weeks);
        // revenueDistributor.getTotalSupplyAtTimestamp(3 weeks);
        // revenueDistributor.getTokensPerWeek(usdc, 2 weeks);
        // revenueDistributor.getTokensPerWeek(usdc, 3 weeks);

        skip(1 weeks);
        // revenueDistributor.getUserState(users.alice);
        // revenueDistributor.getUserBalanceAtTimestamp(users.alice, 2 weeks);

        vm.startPrank(users.alice);
        assertGt(revenueDistributor.claim(usdc, users.alice), 0, "Alice has no claimable revenue");
        

        // Users claim their revenue
        // uint aliceRevenueBefore = revenueInToken.balanceOf(users.alice);
        // uint bobRevenueBefore = revenueInToken.balanceOf(users.bob);

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

    // function depositRevenue(IERC20 token, uint amount) public {
    //     vm.startPrank(users.owner);
    //     token.approve(address(router), amount);
    //     revenueDistributor.depositToken(token, amount);
    //     token.balanceOf(address(revenueDistributor));
    // }

    function generateUserRevenueInUsdc(address user, uint amount) public {
        generateUserRevenue(usdc, user, amount);
    }

    function generateUserRevenueInWnt(address user, uint amount) public {
        generateUserRevenue(wnt, user, amount);
    }

    function generateUserRevenue(IERC20 token, address user, uint amount) public {
        vm.startPrank(users.owner);

        _dealERC20(address(token), users.owner, amount);
        cugar.increase(PositionUtils.getCugarKey(token, user), amount);

        // skip block
        vm.roll(block.number + 1);
        vm.startPrank(user);
    }

    function getCugar(IERC20 token, address user) public view returns (uint) {
        return cugar.get(PositionUtils.getCugarKey(token, user));
    }

    function getCugarInUsdc(address user) public view returns (uint) {
        return cugar.get(PositionUtils.getCugarKey(usdc, user));
    }

    function getCugarInWnt(address user) public view returns (uint) {
        return cugar.get(PositionUtils.getCugarKey(wnt, user));
    }

    function getMaxTime() public view returns (uint) {
        return block.timestamp + MAXTIME;
    }

    function fromPriceToSqrt(uint usdcPerWeth) public pure returns (uint160) {
        return uint160(Math.sqrt(usdcPerWeth * 1e12) << 96) / 1e12 + 1;
    }

    /**
     * @dev Rounds the provided timestamp down to the beginning of the previous week (Thurs 00:00 UTC)
     */
    function _roundDownTimestamp(uint timestamp) private pure returns (uint) {
        // Division by zero or overflows are impossible here.
        return (timestamp / 1 weeks) * 1 weeks;
    }

    /**
     * @dev Rounds the provided timestamp up to the beginning of the next week (Thurs 00:00 UTC)
     */
    function _roundUpTimestamp(uint timestamp) private pure returns (uint) {
        // Overflows are impossible here for all realistic inputs.
        return _roundDownTimestamp(timestamp + 604799);
    }
}
