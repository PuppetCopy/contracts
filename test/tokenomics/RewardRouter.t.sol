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
import {Cugar, CURSOR_INTERVAL} from "src/shared/Cugar.sol";

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
    IUniswapV3Pool[] wntUsdPoolList;

    Oracle.CallConfig callOracleConfig;

    uint8 constant SET_ORACLE_PRICE_ROLE = 3;
    uint8 constant CLAIM_ROLE = 4;
    uint8 constant INCREASE_CONTRIBUTION_ROLE = 5;
    // uint8 constant DECREASE_CONTRIBUTION_ROLE = 6;
    // uint8 constant UPDATE_CURSOR_ROLE = 7;
    uint8 constant VEST_ROLE = 8;
    uint8 constant REWARD_DISTRIBUTOR_ROLE = 9;

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

        votingEscrow = new VotingEscrow(dictator, router, puppetToken);

        cugarStore = new CugarStore(dictator, router, computeCreateAddress(users.owner, vm.getNonce(users.owner) + 1));
        cugar = new Cugar(dictator, cugarStore, votingEscrow);
        dictator.setRoleCapability(INCREASE_CONTRIBUTION_ROLE, address(cugar), cugar.increaseSeedContribution.selector, true);
        // dictator.setRoleCapability(DECREASE_CONTRIBUTION_ROLE, address(cugar), cugar.decreaseContribution.selector, true);
        // dictator.setRoleCapability(UPDATE_CURSOR_ROLE, address(cugar), cugar.seedCursor.selector, true);
        dictator.setRoleCapability(CLAIM_ROLE, address(cugar), cugar.claim.selector, true);

        // votingEscrow.checkpoint();
        dictator.setRoleCapability(VEST_ROLE, address(votingEscrow), votingEscrow.lock.selector, true);
        dictator.setRoleCapability(VEST_ROLE, address(votingEscrow), votingEscrow.withdraw.selector, true);

        rewardRouter = new RewardRouter(
            dictator,
            router,
            votingEscrow,
            cugar,
            RewardRouter.CallConfig({
                lock: RewardLogic.CallLockConfig({
                    votingEscrow: votingEscrow,
                    oracle: oracle,
                    cugarStore: cugarStore,
                    puppetToken: puppetToken,
                    revenueSource: users.owner,
                    rate: 6000
                }),
                exit: RewardLogic.CallExitConfig({
                    oracle: oracle,
                    cugarStore: cugarStore,
                    puppetToken: puppetToken,
                    revenueSource: users.owner,
                    rate: 3000
                })
            })
        );

        dictator.setUserRole(address(votingEscrow), TRANSFER_TOKEN_ROLE, true);
        dictator.setUserRole(address(cugarStore), TRANSFER_TOKEN_ROLE, true);

        dictator.setUserRole(address(rewardRouter), MINT_PUPPET_ROLE, true);
        dictator.setUserRole(address(rewardRouter), VEST_ROLE, true);
        // dictator.setUserRole(address(rewardRouter), DECREASE_CONTRIBUTION_ROLE, true);
        // dictator.setUserRole(address(rewardRouter), UPDATE_CURSOR_ROLE, true);

        dictator.setUserRole(address(rewardRouter), SET_ORACLE_PRICE_ROLE, true);
        dictator.setUserRole(address(rewardRouter), CLAIM_ROLE, true);

        // roles & permissions used for testing
        dictator.setUserRole(users.owner, INCREASE_CONTRIBUTION_ROLE, true);
        dictator.setUserRole(users.owner, CLAIM_ROLE, true);

        wnt.approve(address(router), type(uint).max - 1);
        revenueInTokenList[0].approve(address(router), type(uint).max - 1);
    }

    // function testOptionRevert() public {
    //     vm.expectRevert();
    //     cugar.claim(usdc, users.alice, users.alice);

    //     assertEq(oracle.getPrimaryPoolPrice(), 1e18, "1-1 pool price with 30 decimals precision");
    //     assertEq(oracle.getMaxPrice(usdc), 100e6, "100usdc per puppet");

    //     generateUserRevenueInWnt(users.alice, 1e18);
    //     assertEq(getLockClaimableAmount(wnt, users.alice), 0.6e18);
    //     generateUserRevenueInUsdc(users.alice, 100e6);
    //     assertEq(getLockClaimableAmount(usdc, users.alice), 0.6e18);

    //     vm.expectRevert(Oracle.Oracle__UnavailableSecondaryPrice.selector);
    //     oracle.getSecondaryPrice(wnt);
    //     vm.expectRevert(Oracle.Oracle__UnavailableSecondaryPrice.selector);
    //     oracle.getSecondaryPrice(puppetToken);

    //     vm.expectRevert(abi.encodeWithSelector(RewardLogic.RewardLogic__UnacceptableTokenPrice.selector, 100e6));
    //     rewardRouter.lock(usdc, getMaxTime(), 0.9e6);
    // }

    // function testOption() public {
    //     skip(1 weeks);
    //     generateUserRevenueInWnt(users.yossi, 0.5e18);
    //     rewardRouter.lock(wnt, getMaxTime(), 1e18);

    //     generateUserRevenueInWnt(users.alice, 0.5e18);
    //     rewardRouter.lock(wnt, getMaxTime(), 1e18);

    //     generateUserRevenueInWnt(users.alice, 0.5e18);
    //     rewardRouter.lock(wnt, getMaxTime(), 1e18);

    //     generateUserRevenueInWnt(users.yossi, 0.5e18);
    //     rewardRouter.lock(wnt, getMaxTime(), 1e18);

    //     skip(1 weeks);
    //     vm.startPrank(users.owner);
    //     assertGte(cugar.claim(wnt, users.alice, users.alice), 1e18, "Alice has no claimable revenue");
    //     assertGte(cugar.claim(wnt, users.yossi, users.yossi), 1e18, "Alice has no claimable revenue");

    //     generateUserRevenueInWnt(users.yossi, 0.5e18);
    //     rewardRouter.lock(wnt, getMaxTime(), 1e18);

    //     generateUserRevenueInWnt(users.alice, 0.5e18);
    //     rewardRouter.lock(wnt, getMaxTime(), 1e18);

    //     generateUserRevenueInWnt(users.alice, 0.5e18);
    //     rewardRouter.lock(wnt, getMaxTime(), 1e18);

    //     generateUserRevenueInWnt(users.yossi, 0.5e18);
    //     rewardRouter.lock(wnt, getMaxTime(), 1e18);

    //     skip(1 weeks);
    //     vm.startPrank(users.owner);
    //     assertGte(cugar.claim(wnt, users.alice, users.alice), 1e18, "Alice has no claimable revenue");
    //     assertGte(cugar.claim(wnt, users.yossi, users.yossi), 1e18, "Alice has no claimable revenue");
    // }

    function testCrossedFlow() public {
        generateUserRevenueInWnt(users.alice, 1e18);
        rewardRouter.exit(wnt, 1e18);
        generateUserRevenueInUsdc(users.alice, 100e6);
        rewardRouter.lock(usdc, getMaxTime(), 100e6);
        assertEq(puppetToken.balanceOf(users.alice), 0.3e18);

        generateUserRevenueInUsdc(users.bob, 100e6);
        assertEq(getLockClaimableAmount(usdc, users.bob), 0.6e18);
        assertEq(getExitClaimableAmount(usdc, users.bob), 0.3e18);
        rewardRouter.exit(usdc, 100e6);
        assertEq(puppetToken.balanceOf(users.bob), 0.3e18);

        generateUserRevenueInUsdc(users.bob, 100e6);
        assertEq(getLockClaimableAmount(usdc, users.bob), 0.6e18);
        // rewardRouter.lock(usdc, getMaxTime() / 2, 100e6);
        // assertAlmostEq(votingEscrow.balanceOf(users.bob), Precision.applyBasisPoints(lockRate, 1e18) / 4, 0.01e18);
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
        cugar.increaseSeedContribution(token, users.owner, user, amount);

        // skip(100);

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

    function getCursor(uint _time) internal pure returns (uint) {
        return _time / CURSOR_INTERVAL;
    }
}
