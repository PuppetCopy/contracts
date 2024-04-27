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
import {Oracle} from "src/tokenomics/Oracle.sol";

import {Precision} from "src/utils/Precision.sol";
import {CugarStore} from "src/shared/store/CugarStore.sol";
import {Cugar} from "src/shared/Cugar.sol";

import {SharedSetup} from "test/base/SharedSetup.t.sol";
import {MockWeightedPoolVault} from "test/mocks/MockWeightedPoolVault.sol";
import {MockUniswapV3Pool} from "test/mocks/MockUniswapV3Pool.sol";

import {Role} from "script/Const.sol";

contract RewardRouterTest is SharedSetup {
    MockWeightedPoolVault primaryVaultPool;
    OracleStore oracleStore;
    RewardRouter rewardRouter;
    Oracle oracle;

    IUniswapV3Pool[] wntUsdPoolList;

    Oracle.CallConfig callOracleConfig;

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
        exchangePriceSourceList[0] = Oracle.SecondaryPriceConfig({
            enabled: true, //
            sourceList: wntUsdPoolList,
            twapInterval: 0,
            sourceTokenDeicmals: 6
        });

        primaryVaultPool = new MockWeightedPoolVault();
        primaryVaultPool.initPool(address(puppetToken), address(wnt), 20e18, 80e18);

        address rewardRouterAddress = computeCreateAddress(users.owner, vm.getNonce(users.owner) + 1);

        oracleStore = new OracleStore(dictator, rewardRouterAddress, 1e18);
        oracle = new Oracle(
            dictator,
            oracleStore,
            Oracle.CallConfig({token1: wnt, vault: primaryVaultPool, poolId: 0, updateInterval: 1 days}),
            revenueInTokenList,
            exchangePriceSourceList
        );
        dictator.setRoleCapability(Role.SET_ORACLE_PRICE, address(oracle), oracle.setPrimaryPrice.selector, true);

        rewardRouter = new RewardRouter(
            dictator,
            router,
            votingEscrow,
            cugar,
            RewardRouter.CallConfig({
                lock: RewardLogic.CallLockConfig({
                    votingEscrow: votingEscrow,
                    oracle: oracle,
                    cugar: cugar,
                    puppetToken: puppetToken,
                    revenueSource: users.owner,
                    rate: 6000
                }),
                exit: RewardLogic.CallExitConfig({oracle: oracle, cugar: cugar, puppetToken: puppetToken, revenueSource: users.owner, rate: 3000})
            })
        );

        dictator.setUserRole(address(rewardRouter), Role.MINT_PUPPET, true);
        dictator.setUserRole(address(rewardRouter), Role.VEST, true);
        dictator.setUserRole(address(rewardRouter), Role.CONTRIBUTE, true);

        dictator.setUserRole(address(rewardRouter), Role.SET_ORACLE_PRICE, true);
        dictator.setUserRole(address(rewardRouter), Role.CLAIM, true);

        // roles & permissions used for testing
        dictator.setUserRole(users.owner, Role.INCREASE_CONTRIBUTION, true);

        wnt.approve(address(router), type(uint).max - 1);
        revenueInTokenList[0].approve(address(router), type(uint).max - 1);
    }

    function testOptionRevert() public {
        vm.expectRevert();
        claim(usdc, users.alice);

        assertEq(oracle.getPrimaryPoolPrice(), 1e18, "1-1 pool price with 30 decimals precision");
        assertEq(oracle.getMaxPrice(usdc), 100e6, "100usdc per puppet");

        generateUserRevenueInWnt(users.alice, 1e18);
        assertEq(getLockClaimableAmount(wnt, users.alice), 0.6e18);
        generateUserRevenueInUsdc(users.alice, 100e6);
        assertEq(getLockClaimableAmount(usdc, users.alice), 0.6e18);

        vm.expectRevert(Oracle.Oracle__UnavailableSecondaryPrice.selector);
        oracle.getSecondaryPrice(wnt);
        vm.expectRevert(Oracle.Oracle__UnavailableSecondaryPrice.selector);
        oracle.getSecondaryPrice(puppetToken);

        vm.expectRevert(abi.encodeWithSelector(RewardLogic.RewardLogic__UnacceptableTokenPrice.selector, 100e6));
        lock(usdc, getMaxTime(), 0.9e6, 0.9e6);
    }

    function testExitOption() public {
        skip(1 weeks);
        generateUserRevenueInWnt(users.alice, 1e18);
        lock(wnt, getMaxTime(), 1e18, 0.5e18);
        skip(1 days);

        generateUserRevenueInWnt(users.yossi, 1e18);
        exit(wnt, 1e18, 0.5e18);
        skip(1 weeks);
        vm.startPrank(users.alice);
        assertEq(claim(wnt, users.alice), 2e18);
        assertEq(cugar.getClaimable(cugarStore, wnt, users.yossi), 0);
    }

    function testLockOption() public {
        skip(1 weeks);
        generateUserRevenueInWnt(users.yossi, 0.5e18);
        lock(wnt, getMaxTime(), 1e18, 0.5e18);
        skip(1 days);

        generateUserRevenueInWnt(users.yossi, 0.5e18);
        lock(wnt, getMaxTime(), 1e18, 0.5e18);

        skip(1 days);

        generateUserRevenueInWnt(users.alice, 0.5e18);
        lock(wnt, getMaxTime(), 1e18, 0.5e18);
        skip(1 days);

        generateUserRevenueInWnt(users.alice, 0.5e18);
        lock(wnt, getMaxTime(), 1e18, 0.5e18);

        skip(1 weeks);
        assertEq(claim(wnt, users.alice), 1e18);
        assertEq(wnt.balanceOf(address(cugarStore)), 1e18);
        skip(2 weeks);
        assertEq(cugar.getClaimable(cugarStore, wnt, users.yossi), 1e18);

        generateUserRevenueInWnt(users.bob, 1e18);
        lock(wnt, getMaxTime(), 1e18, 1e18);

        skip(1 weeks);
        cugar.getClaimable(cugarStore, wnt, users.alice);
        assertEq(cugar.getClaimableCursor(cugarStore, wnt, users.yossi, 1 weeks), 1e18);
        assertAlmostEq(cugar.getClaimable(cugarStore, wnt, users.yossi), 1.33e18, 0.005e18);
    }

    function testOptionDecay() public {
        skip(1 weeks);
        generateUserRevenueInWnt(users.yossi, 1e18);
        lock(wnt, getMaxTime(), 1e18, 1e18);

        generateUserRevenueInWnt(users.alice, 1e18);
        skip(1 days);
        lock(wnt, getMaxTime(), 1e18, 1e18);

        assertEq(cugar.getClaimableCursor(cugarStore, wnt, users.yossi, 1 weeks), 1e18);

        skip(1 weeks);

        generateUserRevenueInWnt(users.bob, 1e18);
        lock(wnt, getMaxTime(), 1e18, 1e18);
        skip(1 weeks);

        assertEq(cugar.getClaimableCursor(cugarStore, wnt, users.yossi, 1 weeks), 1e18);
        assertEq(cugar.getClaimableCursor(cugarStore, wnt, users.alice, 1 weeks), 1e18);
        assertAlmostEq(cugar.getClaimable(cugarStore, wnt, users.alice), 1.333e18, 0.005e18);
        assertAlmostEq(cugar.getClaimable(cugarStore, wnt, users.yossi), 1.333e18, 0.005e18);
        assertAlmostEq(cugar.getClaimable(cugarStore, wnt, users.bob), 0.333e18, 0.005e18);

        skip(getMaxTime() / 2);
        assertEq(cugar.getClaimableCursor(cugarStore, wnt, users.yossi, 1 weeks), 1e18);
        assertEq(cugar.getClaimableCursor(cugarStore, wnt, users.alice, 1 weeks), 1e18);
        assertAlmostEq(cugar.getClaimable(cugarStore, wnt, users.alice), 1.333e18, 0.005e18);
        assertAlmostEq(cugar.getClaimable(cugarStore, wnt, users.yossi), 1.333e18, 0.005e18);
        assertAlmostEq(claim(wnt, users.bob), 0.333e18, 0.005e18);
        assertEq(cugar.getClaimable(cugarStore, wnt, users.bob), 0);

        generateUserRevenueInWnt(users.bob, 2e18);
        lock(wnt, getMaxTime(), 1e18, 2e18);
        skip(1 weeks);

        assertAlmostEq(cugar.getClaimable(cugarStore, wnt, users.bob), 1.525e18, 0.005e18);
    }

    function testCrossedFlow() public {
        generateUserRevenueInWnt(users.alice, 1e18);
        exit(wnt, 1e18, 1e18);
        generateUserRevenueInUsdc(users.alice, 100e6);
        lock(usdc, getMaxTime(), 100e6, 100e6);
        assertEq(puppetToken.balanceOf(users.alice), 0.3e18);

        generateUserRevenueInUsdc(users.bob, 100e6);
        assertEq(getLockClaimableAmount(usdc, users.bob), 0.6e18);
        assertEq(getExitClaimableAmount(usdc, users.bob), 0.3e18);
        exit(usdc, 100e6, 100e6);
        assertEq(puppetToken.balanceOf(users.bob), 0.3e18);

        generateUserRevenueInUsdc(users.bob, 100e6);
        assertEq(getLockClaimableAmount(usdc, users.bob), 0.6e18);
        lock(usdc, getMaxTime() / 2, 100e6, 100e6);
        assertAlmostEq(votingEscrow.balanceOf(users.bob), Precision.applyBasisPoints(lockRate, 1e18) / 4, 0.01e18);
    }

    function lock(IERC20 token, uint unlockTime, uint acceptableTokenPrice, uint cugarAmount) public returns (uint) {
        return rewardRouter.lock(cugarStore, token, unlockTime, acceptableTokenPrice, cugarAmount);
    }

    function exit(IERC20 token, uint acceptableTokenPrice, uint cugarAmount) public returns (uint) {
        return rewardRouter.exit(cugarStore, token, acceptableTokenPrice, cugarAmount);
    }

    function claim(IERC20 token, address receiver) public returns (uint) {
        return rewardRouter.claim(cugarStore, token, receiver);
    }

    function getMaxClaimableAmount(IERC20 token, address user) public view returns (uint) {
        uint contribution = cugarStore.getSeedContribution(token, user);
        uint maxPrice = oracle.getMaxPrice(token, oracle.getPrimaryPoolPrice());
        uint maxClaimable = contribution * 1e18 / maxPrice;

        return maxClaimable;
    }

    function getLockClaimableAmount(IERC20 token, address user) public view returns (uint) {
        uint maxClaimable = getMaxClaimableAmount(token, user);
        uint lockMultiplier = RewardLogic.getLockRewardTimeMultiplier(votingEscrow, user, getMaxTime());
        uint lockClaimable = Precision.applyBasisPoints(lockMultiplier, maxClaimable);
        return Precision.applyBasisPoints(lockRate, lockClaimable);
    }

    function getExitClaimableAmount(IERC20 token, address user) public view returns (uint) {
        uint maxClaimable = getMaxClaimableAmount(token, user);
        return Precision.applyBasisPoints(exitRate, maxClaimable);
    }

    function generateUserRevenueInUsdc(address user, uint amount) public {
        generateUserRevenue(usdc, user, amount);
    }

    function generateUserRevenueInWnt(address user, uint amount) public {
        generateUserRevenue(wnt, user, amount);
    }

    function generateUserRevenue(IERC20 token, address user, uint amount) public {
        vm.startPrank(users.owner);

        _dealERC20(address(token), users.owner, amount);
        cugar.increaseSeedContribution(cugarStore, token, user, amount);

        skip(10);

        // skip block
        vm.roll(block.number + 1);
        vm.startPrank(user);
    }

    function getMaxTime() public view returns (uint) {
        return block.timestamp + MAXTIME;
    }

    function fromPriceToSqrt(uint usdcPerWeth) public pure returns (uint160) {
        return uint160(Math.sqrt(usdcPerWeth * 1e12) << 96) / 1e12 + 1;
    }
}
