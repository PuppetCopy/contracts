// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import {IUniswapV3Pool} from "@uniswap/v3-core/interfaces/IUniswapV3Pool.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {OracleLogic} from "src/tokenomics/OracleLogic.sol";
import {OracleStore, OracleStore_SlotSeed} from "src/tokenomics/store/OracleStore.sol";

import {MockWeightedPoolVault} from "test/mocks/MockWeightedPoolVault.sol";
import {BasicSetup} from "test/base/BasicSetup.t.sol";
import {MockUniswapV3Pool} from "test/mocks/MockUniswapV3Pool.sol";

// v3-periphery/contracts/libraries/OracleLibrary.sol

contract OracleTest is BasicSetup {
    OracleLogic oracleLogic;
    OracleStore oracleStore;

    MockWeightedPoolVault vault;
    IUniswapV3Pool[] wntUsdPoolList;

    function setUp() public override {
        super.setUp();

        wntUsdPoolList = new MockUniswapV3Pool[](3);

        // wntUsdPoolList[0] = new MockUniswapV3Pool(4519119652599540205211103);
        wntUsdPoolList[0] = new MockUniswapV3Pool(fromPriceToSqrt(100));
        wntUsdPoolList[1] = new MockUniswapV3Pool(fromPriceToSqrt(100));
        wntUsdPoolList[2] = new MockUniswapV3Pool(fromPriceToSqrt(100));

        vault = new MockWeightedPoolVault();
        vault.initPool(address(puppetToken), address(address(0x0b)), 20e18, 80e18);

        oracleLogic = new OracleLogic(dictator);

        assertEq(oracleLogic.getMedianWntPriceInUsd(wntUsdPoolList, 0), 100e6, "wnt at $100");
        uint seedPuppetUsd = getPuppetExchangeRateInUsdc();
        assertAlmostEq(seedPuppetUsd, 100e6, 1e4, "pool $100 as 20 PUPPET/WETH 80");

        oracleStore = new OracleStore(dictator, address(oracleLogic), seedPuppetUsd, 1 days);

        assertAlmostEq(oracleLogic.getMaxPrice(oracleStore, oracleStore.getLatestSeed().price), 100e6, 1e4, "initial $100");

        dictator.setRoleCapability(PUPPET_MINTER, address(oracleLogic), oracleLogic.syncTokenPrice.selector, true);
    }

    function testMedianWntPriceInUsd() public {
        assertAlmostEq(oracleLogic.getMedianWntPriceInUsd(wntUsdPoolList, 0), 100e6, 1e4, "3 sources, with prices 100, 100, 1");

        IUniswapV3Pool[] memory mockedPools = new IUniswapV3Pool[](5);

        mockedPools[0] = new MockUniswapV3Pool(4557304554737852013346413); // https://www.geckoterminal.com/arbitrum/pools/0xc6962004f452be9203591991d15f6b388e09e8d0
        mockedPools[1] = new MockUniswapV3Pool(4557550662160151886594493); // https://www.geckoterminal.com/arbitrum/pools/0xc31e54c7a869b9fcbecc14363cf510d1c41fa443
        mockedPools[2] = new MockUniswapV3Pool(4556665679493138938331136); // https://www.geckoterminal.com/arbitrum/pools/0x641c00a822e8b671738d32a431a4fb6074e5c79d
        mockedPools[3] = new MockUniswapV3Pool(fromPriceToSqrt(1));
        mockedPools[4] = new MockUniswapV3Pool(fromPriceToSqrt(1));

        assertAlmostEq(oracleLogic.getMedianWntPriceInUsd(mockedPools, 0), 3307e6, 1e6, "5 sources, 2 anomalies");
    }

    function testStoreAndGetPrice() public {
        vault.setPoolBalances(40e18, 80e18);
        assertAlmostEq(getPuppetExchangeRateInUsdc(), 50e6, 1e4, "$50 as 40 PUPPET / 80 WETH");
        vault.setPoolBalances(4000e18, 80e18);
        assertAlmostEq(getPuppetExchangeRateInUsdc(), 5e5, 1e3, "$.5 as 4000 PUPPET / 80 WETH");
        vault.setPoolBalances(40_000e18, 80e18);
        assertAlmostEq(getPuppetExchangeRateInUsdc(), 5e4, 1e3, "$.005 as 40,000 PUPPET / 80 WETH");
        vault.setPoolBalances(2e18, 80e18);
        assertAlmostEq(getPuppetExchangeRateInUsdc(), 1_000e6, 1e3, "$1000 as 2 PUPPET / 80 WETH");
        vault.setPoolBalances(20e18, 80_000_000e18);
        assertAlmostEq(getPuppetExchangeRateInUsdc(), 100_000_000e6, 1e6, "$100,000,000 as 20 PUPPET / 80,000,000 WETH");
        vault.setPoolBalances(20_000_000e18, 80e18);
        assertAlmostEq(getPuppetExchangeRateInUsdc(), 100, 1e1, "$0000.1 as 20,000,000 PUPPET / 80 WETH");

        vault.setPoolBalances(2_000e18, 0);
        vm.expectRevert();
        getPuppetExchangeRateInUsdc();
        vault.setPoolBalances(0, 2_000e18);
        vm.expectRevert();
        getPuppetExchangeRateInUsdc();
    }

    function testSlotMinMaxPrice() public {
        _stepSlot();
        _storeStepSlot(80_000_000e18);
        _storePrice(80e18);
        _storeStepSlot(80_000_000e18);
        _storePrice(80e18);
        _storeStepSlot(80_000_000e18);
        _storePrice(80e18);

        assertAlmostEq(_storeStepSlot(80e18), 100_000_000e6, 1e6, "set inital $2");
        assertAlmostEq(oracleLogic.getMinPrice(oracleStore, _storeStepSlot(80_000_000e18)), 100e6, 1e2, "set inital $2");
    }

    function testMedianHigh() public {
        _storeStepSlot(40e18);
        _storeStepSlot(70e18);
        _storeStepSlot(20e18);
        _storeStepSlot(60e18);
        _storeStepSlot(30e18);
        _storeStepSlot(50e18);

        assertAlmostEq(_storeStepSlot(10e18), 50e6, 1e4);
        assertAlmostEq(_storeStepSlot(10e18), 37e6, 1e6);
        assertAlmostEq(_storeStepSlot(10e18), 25e6, 1e2);
    }

    function _storeStepSlot(uint priceInWnt) internal returns (uint) {
        _stepSlot();
        uint price = _storePrice(priceInWnt);

        return price;
    }

    function _stepSlot() internal {
        OracleStore_SlotSeed memory update = oracleStore.getLatestSeed();
        skip(update.updateInterval);
    }

    function _storePrice(uint balanceInWnt) internal returns (uint) {
        OracleStore_SlotSeed memory update = oracleStore.getLatestSeed();
        vm.roll(update.blockNumber + 1);
        vault.setPoolBalances(20e18, balanceInWnt);
        return oracleLogic.syncTokenPrice(wntUsdPoolList, vault, oracleStore, 0, 0);
    }

    function getPuppetExchangeRateInUsdc() public view returns (uint) {
        return oracleLogic.getPuppetExchangeRateInUsdc(wntUsdPoolList, vault, 0, 0);
    }

    function fromPriceToSqrt(uint usdcPerWeth) public pure returns (uint160) {
        return uint160((Math.sqrt(usdcPerWeth * 1e12) << 96) / 1e12 + 1);
    }
}
