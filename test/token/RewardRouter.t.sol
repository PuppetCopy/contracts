// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {RewardRouter} from "src/token/RewardRouter.sol";
import {OracleStore} from "src/token/store/OracleStore.sol";
import {Puppet} from "src/token/Puppet.sol";
import {VotingEscrow, MAXTIME} from "src/token/VotingEscrow.sol";
import {RewardLogic} from "src/token/logic/RewardLogic.sol";
import {Oracle} from "src/token/Oracle.sol";

import {Precision} from "src/utils/Precision.sol";
import {RewardStore} from "src/token/store/RewardStore.sol";

import {BasicSetup} from "test/base/BasicSetup.t.sol";
import {MockWeightedPoolVault} from "test/mocks/MockWeightedPoolVault.sol";
import {MockUniswapV3Pool} from "test/mocks/MockUniswapV3Pool.sol";

contract RewardRouterTest is BasicSetup {
    VotingEscrow votingEscrow;
    MockWeightedPoolVault primaryVaultPool;
    OracleStore oracleStore;
    RewardRouter rewardRouter;
    RewardStore rewardStore;
    Oracle oracle;

    RewardRouter.CallConfig rewardRouterConfig;

    uint public lockRate = 6000;
    uint public exitRate = 3000;

    function setUp() public override {
        vm.warp(1716671477);

        super.setUp();

        votingEscrow = new VotingEscrow(dictator, router, puppetToken);
        dictator.setPermission(router, address(votingEscrow), router.transfer.selector);

        IUniswapV3Pool[] memory wntUsdPoolList = new IUniswapV3Pool[](1);
        wntUsdPoolList[0] = new MockUniswapV3Pool(fromPriceToSqrt(100), address(wnt), address(usdc));

        Oracle.SecondaryPriceConfig[] memory exchangePriceSourceList = new Oracle.SecondaryPriceConfig[](1);
        exchangePriceSourceList[0] = Oracle.SecondaryPriceConfig({enabled: true, sourceList: wntUsdPoolList, twapInterval: 0, token: usdc});

        primaryVaultPool = new MockWeightedPoolVault();
        primaryVaultPool.initPool(address(wnt), address(puppetToken), 20e18, 8000e18);

        (, uint[] memory balances,) = primaryVaultPool.getPoolTokens(0);

        uint initalPrice = (balances[0] * 80e18) / (balances[1] * 20);

        oracleStore = new OracleStore(dictator, initalPrice);
        oracle = new Oracle(
            dictator,
            oracleStore,
            Oracle.PrimaryPriceConfig({token: wnt, vault: primaryVaultPool, poolId: 0, updateInterval: 1 days}),
            exchangePriceSourceList
        );
        dictator.setAccess(oracleStore, address(oracle));

        rewardStore = new RewardStore(dictator, router);
        dictator.setPermission(router, address(rewardStore), router.transfer.selector);
        rewardRouterConfig = RewardRouter.CallConfig({
            oracle: oracle,
            lockRate: lockRate,
            exitRate: exitRate,
            distributionTimeframe: 1 weeks,
            revenueSource: users.owner
        });
        rewardRouter = new RewardRouter(dictator, router, votingEscrow, puppetToken, rewardStore, rewardRouterConfig);

        dictator.setAccess(rewardStore, address(rewardRouter));

        dictator.setAccess(votingEscrow, address(rewardRouter));
        dictator.setPermission(oracle, address(rewardRouter), oracle.setPrimaryPrice.selector);
        dictator.setPermission(puppetToken, address(rewardRouter), puppetToken.mint.selector);

        // permissions used for testing
        dictator.setAccess(rewardStore, users.owner);
        wnt.approve(address(router), type(uint).max - 1);
        for (uint i = 0; i < exchangePriceSourceList.length; i++) {
            exchangePriceSourceList[i].token.approve(address(router), type(uint).max - 1);
        }

        assertEq(oracle.getPrimaryPoolPrice(), 0.01e18, ".01 WNT per PUPPET");
        assertEq(oracle.getSecondaryPoolPrice(usdc), 100e6, "100 USDC per WNT");
        assertEq(oracle.getMaxPrice(usdc), 1e6, "1 USDC per PUPPET");
    }

    // function testOptionRevert() public {
    //     vm.expectRevert(RewardLogic.RewardLogic__NoClaimableAmount.selector);
    //     claim(usdc, users.alice);

    //     vm.expectRevert(Oracle.Oracle__UnavailableSecondaryPrice.selector);
    //     oracle.getSecondaryPrice(wnt);
    //     vm.expectRevert(Oracle.Oracle__UnavailableSecondaryPrice.selector);
    //     oracle.getSecondaryPrice(puppetToken);
    //     vm.expectRevert(Oracle.Oracle__UnavailableSecondaryPrice.selector);
    //     oracle.getSecondaryPrice(IERC20(address(0)));

    //     generateUserRevenue(usdc, users.alice, 100e6);
    //     vm.expectRevert(abi.encodeWithSelector(RewardLogic.RewardLogic__UnacceptableTokenPrice.selector, 1e6));
    //     rewardRouter.lock(usdc, getMaxTime(), 0.99e6, 100e6);
    // }

    // function testExitOption() public {
    //     lock(wnt, users.bob, getMaxTime(), 0.01e18, 0.5e18);

    //     exit(usdc, users.alice, 1e6, 100e6);
    //     skip(rewardRouterConfig.distributionTimeframe);
    //     claim(usdc, users.bob);
    //     assertEq(puppetToken.balanceOf(users.alice), 30e18);
    //     assertApproxEqAbs(usdc.balanceOf(users.bob), 100e6, 0.01e6);

    //     exit(usdc, users.alice, 1e6, 100e6);
    //     skip(rewardRouterConfig.distributionTimeframe + 1 days);
    //     assertApproxEqAbs(rewardRouter.getClaimable(usdc, users.bob), 100e6, 0.01e6);
    // }

    function testLockOption() public {
        lock(wnt, users.yossi, MAXTIME, 0.01e18, 1e18);
        skip(rewardRouterConfig.distributionTimeframe);
        skip(rewardRouterConfig.distributionTimeframe);

        lock(wnt, users.alice, MAXTIME, 0.01e18, 1e18);
        skip(rewardRouterConfig.distributionTimeframe);

        assertApproxEqAbs(rewardRouter.getClaimable(wnt, users.yossi), 1.5e18, 0.1e18);
        assertApproxEqAbs(rewardRouter.getClaimable(wnt, users.alice), 0.5e18, 0.1e18);

        assertApproxEqAbs(rewardRouter.getClaimable(wnt, users.alice) + rewardRouter.getClaimable(wnt, users.yossi), 2e18, 0.001e18);
        // assertEq(
        //     votingEscrow.balanceOf(users.yossi) + votingEscrow.balanceOf(users.alice),
        //     votingEscrow.totalSupply()
        // );

        // skip(rewardRouterConfig.distributionTimeframe / 2);

        // assertApproxEqAbs(rewardRouter.getClaimable(wnt, users.yossi), 1.5e18, 0.01e18);
        // assertApproxEqAbs(rewardRouter.getClaimable(wnt, users.alice), 0.5e18, 0.01e18);

        // assertApproxEqAbs(rewardRouter.claim(wnt, users.alice), 0.5e18, 0.01e18);
        // assertEq(rewardRouter.getClaimable(wnt, users.alice), 0);

        // // lock(wnt, users.alice, getMaxTime(), 0.01e18, 1e18);
        // skip(rewardRouterConfig.distributionTimeframe / 2);
        // lock(wnt, users.bob, getMaxTime(), 0.01e18, 1e18);

        // assertApproxEqAbs(rewardRouter.getClaimable(wnt, users.yossi), 0.125e18, 0.01e18);

        // assertApproxEqAbs(rewardRouter.getClaimable(wnt, users.bob), 0.125e18, 0.01e18);

        // skip(rewardRouterConfig.distributionTimeframe / 2);

        // assertApproxEqAbs(rewardRouter.getClaimable(wnt, users.bob), 0.25e18, 0.01e18);
    }

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

    function lock(IERC20 token, address user, uint unlockTime, uint acceptableTokenPrice, uint cugarAmount) public returns (uint) {
        rewardRouter.distribute(token);
        generateUserRevenue(token, user, cugarAmount);

        uint claimableInToken = rewardRouter.lock(token, unlockTime, acceptableTokenPrice, cugarAmount);

        return claimableInToken;
    }

    function exit(IERC20 token, address user, uint acceptableTokenPrice, uint cugarAmount) public returns (uint) {
        generateUserRevenue(token, user, cugarAmount);
        uint claimableInToken = rewardRouter.exit(token, acceptableTokenPrice, cugarAmount, user);

        return claimableInToken;
    }

    function claim(IERC20 token, address user) public returns (uint) {
        vm.startPrank(user);

        return rewardRouter.claim(token, user);
    }

    function getMaxClaimableAmount(IERC20 token, address user) public view returns (uint) {
        uint contribution = rewardStore.getSeedContribution(token, user);
        uint maxPrice = oracle.getMaxPrice(token, oracle.getPrimaryPoolPrice());
        uint maxClaimable = contribution * 1e18 / maxPrice;

        return maxClaimable;
    }

    function getLockClaimableAmount(IERC20 token, address user) public view returns (uint) {
        uint maxClaimable = getMaxClaimableAmount(token, user);
        return Precision.applyBasisPoints(lockRate, maxClaimable);
    }

    function getExitClaimableAmount(IERC20 token, address user) public view returns (uint) {
        uint maxClaimable = getMaxClaimableAmount(token, user);
        return Precision.applyBasisPoints(exitRate, maxClaimable);
    }

    function generateUserRevenue(IERC20 token, address user, uint amount) public {
        vm.startPrank(users.owner);

        _dealERC20(address(token), users.owner, amount);
        rewardStore.commitReward(token, user, amount);

        // skip block
        vm.roll(block.number + 1);
        vm.startPrank(user);
    }

    function fromPriceToSqrt(uint usdcPerWeth) public pure returns (uint160) {
        return uint160(Math.sqrt(usdcPerWeth * 1e12) << 96) / 1e12 + 1;
    }
}
