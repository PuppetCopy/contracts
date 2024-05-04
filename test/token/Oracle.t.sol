// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IUniswapV3Pool} from "@uniswap/v3-core/interfaces/IUniswapV3Pool.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {PoolUtils} from "src/utils/PoolUtils.sol";
import {OracleStore} from "src/token/store/OracleStore.sol";
import {Oracle} from "src/token/Oracle.sol";

import {MockWeightedPoolVault} from "test/mocks/MockWeightedPoolVault.sol";
import {BasicSetup} from "test/base/BasicSetup.t.sol";
import {MockUniswapV3Pool} from "test/mocks/MockUniswapV3Pool.sol";

contract OracleTest is BasicSetup {
    OracleStore usdPerWntStore;
    OracleStore oracleStore;

    MockWeightedPoolVault poolVault;
    IUniswapV3Pool[] wntUsdPoolList;

    Oracle oracle;

    function setUp() public override {
        super.setUp();

        wntUsdPoolList = new MockUniswapV3Pool[](3);
        wntUsdPoolList[0] = new MockUniswapV3Pool(fromPriceToSqrt(100), address(wnt), address(usdc));
        wntUsdPoolList[1] = new MockUniswapV3Pool(fromPriceToSqrt(100), address(wnt), address(usdc));
        wntUsdPoolList[2] = new MockUniswapV3Pool(fromPriceToSqrt(100), address(usdc), address(wnt));

        Oracle.SecondaryPriceConfig[] memory exchangePriceSourceList = new Oracle.SecondaryPriceConfig[](1);
        exchangePriceSourceList[0] = Oracle.SecondaryPriceConfig({
            enabled: true, //
            token: usdc,
            twapInterval: 0,
            sourceList: wntUsdPoolList
        });

        poolVault = new MockWeightedPoolVault();
        poolVault.initPool(address(wnt), address(puppetToken), 20e18, 8000e18);

        (, uint[] memory balances,) = poolVault.getPoolTokens(0);

        uint tokenBalance = balances[1];
        uint primaryBalance = balances[0];

        uint initalPrice = (tokenBalance * 20e18) / (primaryBalance * 80);

        oracleStore = new OracleStore(dictator, initalPrice);
        oracle = new Oracle(
            dictator,
            oracleStore,
            Oracle.PrimaryPriceConfig({token: wnt, vault: poolVault, poolId: 0, updateInterval: 1 days}),
            exchangePriceSourceList
        );
        dictator.setAccess(oracleStore, address(oracle));

        assertEq(oracle.getPrimaryPoolPrice(), 100e18, "0.01 wnt per puppet");
        assertEq(oracle.getSecondaryPoolPrice(usdc), 100e6, "100 usd per wnt");
        assertEq(oracle.getSecondaryPrice(usdc), 1e6, "1 usd per puppet");
        assertEq(oracle.getMaxPrice(usdc), 1e6, "1 max usd per puppet");

        // permissions for testing purposes
        dictator.setPermission(oracle, users.owner, oracle.setPrimaryPrice.selector);
    }

    function testMedianWntPriceInUsd() public {
        IUniswapV3Pool[] memory mockedPools = new IUniswapV3Pool[](5);

        mockedPools[0] = new MockUniswapV3Pool(4557304554737852013346413, address(wnt), address(usdc)); // https://www.geckoterminal.com/arbitrum/pools/0xc6962004f452be9203591991d15f6b388e09e8d0
        mockedPools[1] = new MockUniswapV3Pool(4557550662160151886594493, address(wnt), address(usdc)); // https://www.geckoterminal.com/arbitrum/pools/0xc31e54c7a869b9fcbecc14363cf510d1c41fa443
        mockedPools[2] = new MockUniswapV3Pool(4556665679493138938331136, address(wnt), address(usdc)); // https://www.geckoterminal.com/arbitrum/pools/0x641c00a822e8b671738d32a431a4fb6074e5c79d
        mockedPools[3] = new MockUniswapV3Pool(fromPriceToSqrt(1), address(wnt), address(usdc));
        mockedPools[4] = new MockUniswapV3Pool(fromPriceToSqrt(1), address(wnt), address(usdc));

        assertApproxEqAbs(PoolUtils.getTwapMedianPrice(mockedPools, 0), 3307.76e6, 0.05e6, "5 sources, 2 anomalies");
    }

    // function testUsdcPrice() public {
    //     // (80 * 0.2) / (20 * 0.80)
    //     poolVault.setPoolBalances(20e18, 80e18);
    //     assertEq(oracle.getSecondaryPrice(usdc), 100e6);
    //     poolVault.setPoolBalances(40e18, 80e18);
    //     assertEq(oracle.getSecondaryPrice(usdc), 200e6);
    //     poolVault.setPoolBalances(20e18, 40e18);
    //     assertEq(oracle.getSecondaryPrice(usdc), 200e6);
    //     poolVault.setPoolBalances(20e18, 160e18);
    //     assertEq(oracle.getSecondaryPrice(usdc), 50e6);
    //     poolVault.setPoolBalances(20e18, 16000e18);
    //     assertEq(oracle.getSecondaryPrice(usdc), 0.5e6);
    //     poolVault.setPoolBalances(20e18, 160000e18);
    //     assertEq(oracle.getSecondaryPrice(usdc), 0.05e6);
    //     poolVault.setPoolBalances(40e18, 160000000e18);
    //     assertEq(oracle.getSecondaryPrice(usdc), 0.0001e6);
    //     poolVault.setPoolBalances(20_000_000e18, 80e18);
    //     assertEq(oracle.getSecondaryPrice(usdc), 100_000_000e6);
    //     poolVault.setPoolBalances(20e18, 8e18);
    //     assertEq(oracle.getSecondaryPrice(usdc), 1_000e6);

    //     poolVault.setPoolBalances(2_000e18, 0);
    //     vm.expectRevert();
    //     oracle.getSecondaryPrice(usdc);
    //     poolVault.setPoolBalances(0, 2_000e18);
    //     vm.expectRevert();
    //     oracle.getSecondaryPrice(usdc);
    // }

    function testSlotMinMaxPrice() public {
        _stepSlot();

        _storeStepInUsdc(20e18);

        // assertEq(_storeStepInUsdc(4000e18), 200e6);
        // assertEq(_storeStepInUsdc(4000e18), 200e6);
        // assertEq(_storeStepInUsdc(4000e18), 200e6);
        // assertEq(_storeStepInUsdc(4000e18), 200e6);
        // assertEq(_storeStepInUsdc(4000e18), 200e6);
        // assertEq(_storeStepInUsdc(4000e18), 200e6);

        // _storeStepInUsdc(200e18);
        // assertEq(oracle.getMinPrice(usdc), 10e6);
    }

    // function testMedianHigh() public {
    //     _storeStepInWnt(1e18);
    //     _storeStepInWnt(2e18);
    //     _storeStepInWnt(4e18);
    //     _storeStepInWnt(8e18);
    //     _storeStepInWnt(16e18);
    //     _storeStepInWnt(32e18);
    //     _storeStepInWnt(64e18);

    //     assertEq(oracleStore.medianMax(), 0.004e18);

    //     _storeStepInWnt(128e18);
    //     assertEq(oracleStore.medianMax(), 0.008e18);
    //     _storeStepInWnt(256e18);
    //     assertEq(oracleStore.medianMax(), 0.016e18);
    // }

    function _storeStepInUsdc(uint balanceInWnt) internal returns (uint) {
        return _storeStep(balanceInWnt, usdc);
    }

    function _storeStepInWnt(uint balanceInWnt) internal returns (uint) {
        return _storeStep(balanceInWnt, wnt);
    }

    function _storeStep(uint balanceInWnt, IERC20 token) internal returns (uint) {
        _stepSlot();
        _setPoolBalance(balanceInWnt);
        oracle.setPrimaryPrice();

        return oracle.getMaxPrice(token);
    }

    function _stepSlot() internal {
        skip(1 days);
    }

    function _setPoolBalance(uint balanceInWnt) internal {
        OracleStore.SeedSlot memory seed = oracleStore.getLatestSeed();
        vm.roll(seed.blockNumber + 1);
        poolVault.setPoolBalances(balanceInWnt, 8000e18);
    }

    function fromPriceToSqrt(uint usdcPerWeth) public pure returns (uint160) {
        return uint160((Math.sqrt(usdcPerWeth * 1e12) << 96) / 1e12 + 1);
    }
}
