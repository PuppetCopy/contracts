// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IUniswapV3Pool} from "@uniswap/v3-core/interfaces/IUniswapV3Pool.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {OracleStore} from "src/tokenomics/store/OracleStore.sol";

import {OracleLogic} from "./../../src/tokenomics/logic/OracleLogic.sol";

import {Oracle} from "./../../src/Oracle.sol";

import {MockWeightedPoolVault} from "test/mocks/MockWeightedPoolVault.sol";
import {BasicSetup} from "test/base/BasicSetup.t.sol";
import {MockUniswapV3Pool} from "test/mocks/MockUniswapV3Pool.sol";

contract OracleTest is BasicSetup {
    uint8 constant SET_ORACLE_PRICE_ROLE = 3;

    OracleStore usdPerWntStore;
    OracleStore puppetPerWntStore;

    MockWeightedPoolVault puppetWntPoolVault;
    IUniswapV3Pool[] wntUsdPoolList;

    Oracle oracle;

    Oracle.CallConfig callOracleConfig;

    IERC20[] revenueTokenList;

    function setUp() public override {
        super.setUp();

        revenueTokenList = new IERC20[](0);
        revenueTokenList[0] = usdc;

        OracleLogic.ExchangePriceSourceConfig[] memory exchangePriceSourceList = new OracleLogic.ExchangePriceSourceConfig[](1);
        exchangePriceSourceList[0] =
            OracleLogic.ExchangePriceSourceConfig({enabled: true, sourceList: wntUsdPoolList, twapInterval: 0, sourceTokenDeicmals: 6});

        wntUsdPoolList = new MockUniswapV3Pool[](3);

        wntUsdPoolList[0] = new MockUniswapV3Pool(fromPriceToSqrt(100));
        wntUsdPoolList[1] = new MockUniswapV3Pool(fromPriceToSqrt(100));
        wntUsdPoolList[2] = new MockUniswapV3Pool(fromPriceToSqrt(100));

        puppetWntPoolVault = new MockWeightedPoolVault();
        puppetWntPoolVault.initPool(address(puppetToken), address(0x0b), 20e18, 80e18);

        address oracleAddress = computeCreateAddress(users.owner, vm.getNonce(users.owner) + 1);

        puppetPerWntStore = new OracleStore(dictator, oracleAddress, 1e18);

        callOracleConfig = Oracle.CallConfig({store: puppetPerWntStore, vault: puppetWntPoolVault, wnt: wnt, poolId: 0, updateInterval: 1 days});
        oracle = new Oracle(
            dictator,
            Oracle.CallConfig({store: puppetPerWntStore, vault: puppetWntPoolVault, wnt: wnt, poolId: 0, updateInterval: 1 days}),
            revenueTokenList,
            exchangePriceSourceList
        );
        dictator.setRoleCapability(SET_ORACLE_PRICE_ROLE, address(oracle), oracle.storePrice.selector, true);
        dictator.setUserRole(users.owner, SET_ORACLE_PRICE_ROLE, true);

        oracle.storePrice();

        uint usdPerWnt = OracleLogic.getTokenPerWntUsingTwapMedian(wntUsdPoolList, 0);
        uint tokenPerWnt = oracle.getMaxPrice();
        uint usdPerToken = oracle.getMaxPriceInToken(usdc);

        assertEq(usdPerWnt, 100e6, "100 usd per wnt");
        assertEq(tokenPerWnt, 1e30, "1 puppet per wnt");
        assertEq(usdPerToken, 100e30, "100 usd per puppet");

        assertEq(OracleLogic.getTokenPerWntUsingTwapMedian(wntUsdPoolList, 0), 100e6, "100 usd per wnt");
        assertEq(oracle.getMaxPrice(), 1e30, "100 usd per wnt");
    }

    function testMedianWntPriceInUsd() public {
        IUniswapV3Pool[] memory mockedPools = new IUniswapV3Pool[](5);

        mockedPools[0] = new MockUniswapV3Pool(4557304554737852013346413); // https://www.geckoterminal.com/arbitrum/pools/0xc6962004f452be9203591991d15f6b388e09e8d0
        mockedPools[1] = new MockUniswapV3Pool(4557550662160151886594493); // https://www.geckoterminal.com/arbitrum/pools/0xc31e54c7a869b9fcbecc14363cf510d1c41fa443
        mockedPools[2] = new MockUniswapV3Pool(4556665679493138938331136); // https://www.geckoterminal.com/arbitrum/pools/0x641c00a822e8b671738d32a431a4fb6074e5c79d
        mockedPools[3] = new MockUniswapV3Pool(fromPriceToSqrt(1));
        mockedPools[4] = new MockUniswapV3Pool(fromPriceToSqrt(1));

        assertAlmostEq(OracleLogic.getTokenPerWntUsingTwapMedian(mockedPools, 0), 3307.76e6, 0.05e6, "5 sources, 2 anomalies");
    }

    function testUsdcPrice() public {
        puppetWntPoolVault.setPoolBalances(40e18, 80e18);
        assertAlmostEq(oracle.getMaxPriceInToken(usdc), 50e30, 0.1e30, "$50 as 40 PUPPET / 80 WETH");
        puppetWntPoolVault.setPoolBalances(4000e18, 80e18);
        assertAlmostEq(oracle.getMaxPriceInToken(usdc), 0.5e30, 0.5e30, "$.5 as 4000 PUPPET / 80 WETH");
        puppetWntPoolVault.setPoolBalances(40_000e18, 80e18);
        assertAlmostEq(oracle.getMaxPriceInToken(usdc), 0.05e30, 0.5e30, "$.005 as 40,000 PUPPET / 80 WETH");
        puppetWntPoolVault.setPoolBalances(2e18, 80e18);
        assertAlmostEq(oracle.getMaxPriceInToken(usdc), 1_000e30, 0.5e30, "$1000 as 2 PUPPET / 80 WETH");
        puppetWntPoolVault.setPoolBalances(20e18, 80_000_000e18);
        assertAlmostEq(oracle.getMaxPriceInToken(usdc), 100_000_000e30, 0.5e30, "$100,000,000 as 20 PUPPET / 80,000,000 WETH");
        puppetWntPoolVault.setPoolBalances(20_000_000e18, 80e18);
        assertAlmostEq(oracle.getMaxPriceInToken(usdc), 0.0001e30, 0.1e30, "$0000.1 as 20,000,000 PUPPET / 80 WETH");

        puppetWntPoolVault.setPoolBalances(2_000e18, 0);
        vm.expectRevert();
        oracle.getMaxPriceInToken(usdc);
        puppetWntPoolVault.setPoolBalances(0, 2_000e18);
        vm.expectRevert();
        oracle.getMaxPriceInToken(usdc);
    }

    function testSlotMinMaxPrice() public {
        _stepSlot();
        _storePrice(90e18);
        _storePrice(60e18);

        assertEq(_storeStepInUsd(160e18), 200e30, "200 usd per puppet");
        assertEq(_storeStepInUsd(40e18), 50e30, "50 usd per puppet");
    }

    function testMedianHigh() public {
        _storeStepInWnt(1e18);
        _storeStepInWnt(2e18);
        _storeStepInWnt(4e18);
        _storeStepInWnt(8e18);
        _storeStepInWnt(16e18);
        _storeStepInWnt(32e18);
        _storeStepInWnt(64e18);

        // [1250000000000000000000000000000 [1.25e30], 80000000000000000000000000000000 [8e31], 40000000000000000000000000000000 [4e31],
        // 20000000000000000000000000000000 [2e31], 10000000000000000000000000000000 [1e31], 5000000000000000000000000000000 [5e30],
        // 2500000000000000000000000000000 [2.5e30]]
        // 1.25e30, 8e31, 4e31, 2e31, 1e31, 5e30, 2.5e30

        assertAlmostEq(puppetPerWntStore.medianMax(), 1e31, 1e30);

        _storeStepInWnt(64e18);
        assertAlmostEq(puppetPerWntStore.medianMax(), 5e30, 1e30);
        _storeStepInWnt(64e18);
        assertAlmostEq(puppetPerWntStore.medianMax(), 2.5e30, 1e30);
    }

    function _storeStepInUsd(uint balanceInWnt) internal returns (uint) {
        _storeStep(balanceInWnt);

        oracle.storePrice();

        return oracle.getMaxPriceInToken(usdc);
    }

    function _storeStepInWnt(uint balanceInWnt) internal returns (uint) {
        _storeStep(balanceInWnt);

        oracle.storePrice();

        return oracle.getMaxPrice();
    }

    function _storeStep(uint balanceInWnt) internal {
        _stepSlot();
        _storePrice(balanceInWnt);
    }

    function _stepSlot() internal {
        skip(callOracleConfig.updateInterval);
    }

    function _storePrice(uint balanceInWnt) internal {
        OracleStore.SlotSeed memory seed = puppetPerWntStore.getLatestSeed();
        vm.roll(seed.blockNumber + 1);
        puppetWntPoolVault.setPoolBalances(20e18, balanceInWnt);
    }

    function fromPriceToSqrt(uint usdcPerWeth) public pure returns (uint160) {
        return uint160((Math.sqrt(usdcPerWeth * 1e12) << 96) / 1e12 + 1);
    }
}
