// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IUniswapV3Pool} from "@uniswap/v3-core/interfaces/IUniswapV3Pool.sol";
import {IVault} from "@balancer-labs/v2-interfaces/vault/IVault.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {OracleStore, SLOT_COUNT} from "./store/OracleStore.sol";
import {UniV3Prelude} from "./../utils/UniV3Prelude.sol";

/**
 * @title OracleLogic
 * @dev This contract mitigates price manipulation by:
 *
 * 1. Storing prices in seven different time slots to record the highest and lowest prices.
 * 2. Using the median of the highest slot prices as a reference to filter out outliers of of extreme values.
 * 3. Comparing the latest price with the median slot high and using the greater of the two to safeguard against undervaluation.
 * 4. Checking for price updates within the same block to protect against flash loan attacks that could temporarily distort prices.
 *
 * -- Flashloan
 * assuming attacker tries to flashloan a low price to affect the price
 * low price settlment manipulation would be mitigated by taking previous higher settled price within the same block
 * - DDOS
 * settlment has to be below Acceptable Price check can an attacker prevent other tx's from being settled?
 * there doesn't seem to have an ecnonomical sense but it could be a case
 *
 */
library OracleLogic {
    event OracleLogic__PriceUpdate(uint timestamp, uint price);
    event OracleLogic__SlotSettled(uint updateInterval, uint timestamp, uint minPrice, uint maxPrice);
    event OracleLogic__SyncDelayedSlot(uint updateInterval, uint seedTimestamp, uint blockTimestamp, uint delayCount, uint price);

    struct CallConfig {
        IUniswapV3Pool[] wntUsdSourceList;
        IVault vault;
        OracleStore tokenPerWntStore;
        // OracleStore usdPerWntStore;
        bytes32 poolId;
        uint32 twapInterval;
        uint updateInterval;
    }

    function getMaxPrice(OracleStore store, uint latestPrice) public view returns (uint) {
        return Math.max(store.medianMax(), latestPrice);
    }

    function getMinPrice(OracleStore store, uint latestPrice) public view returns (uint) {
        return Math.min(store.medianMin(), latestPrice);
    }

    function getTokenPerUsd(CallConfig calldata callConfig) public view returns (uint usdPerToken) {
        uint usdPerWnt = getUsdPerWntUsingTwapMedian(callConfig.wntUsdSourceList, callConfig.twapInterval);
        uint tokenPerWnt = getTokenPerWnt(callConfig.vault, callConfig.poolId);
        usdPerToken = usdPerWnt * 1e30 / tokenPerWnt;
    }

    function getTokenPerWnt(IVault vault, bytes32 poolId) public view returns (uint price) {
        (, uint[] memory balances,) = vault.getPoolTokens(poolId);

        uint tokenBalance = balances[0];
        uint nSlotBalance = balances[1];
        uint precision = 10 ** 30;

        uint balanceRatio = (tokenBalance * 80 * precision) / (nSlotBalance * 20);
        price = balanceRatio;

        if (price == 0) revert OracleLogic__NonZeroPrice();
    }

    function getUsdPerWntUsingTwapMedian(IUniswapV3Pool[] memory wntUsdSourceList, uint32 twapInterval) public view returns (uint medianPrice) {
        uint sourceListLength = wntUsdSourceList.length;
        if (sourceListLength < 3) revert OracleLogic__NotEnoughSources();

        uint[] memory priceList = new uint[](sourceListLength);
        uint medianIndex = (sourceListLength - 1) / 2; // Index of the median after the array is sorted

        // Initialize the first element
        priceList[0] = UniV3Prelude.getTwapPrice(wntUsdSourceList[0], 18, twapInterval);

        for (uint i = 1; i < sourceListLength; i++) {
            uint currentPrice = UniV3Prelude.getTwapPrice(wntUsdSourceList[i], 18, twapInterval);

            uint j = i;
            while (j > 0 && priceList[j - 1] > currentPrice) {
                priceList[j] = priceList[j - 1];
                j--;
            }
            priceList[j] = currentPrice;
        }

        medianPrice = priceList[medianIndex] * 1e24;
    }

    // state
    function syncPrices(CallConfig memory callConfig) internal returns (uint usdPerWnt, uint tokenPerWnt, uint usdPerToken) {
        usdPerWnt = getUsdPerWntUsingTwapMedian(callConfig.wntUsdSourceList, callConfig.twapInterval);
        uint exchangeTokenPerWnt = getTokenPerWnt(callConfig.vault, callConfig.poolId);
        tokenPerWnt = _storeAndGetMax(callConfig.tokenPerWntStore, callConfig.updateInterval, exchangeTokenPerWnt);
        usdPerToken = usdPerWnt * 1e30 / tokenPerWnt;
    }

    // Internal

    function _storeAndGetMax(OracleStore store, uint updateInterval, uint price) internal returns (uint) {
        OracleStore.SlotSeed memory seed = store.getLatestSeed();

        if (seed.blockNumber == block.number && seed.price > price) {
            return getMaxPrice(store, seed.price);
        }

        _storeMinMax(store, updateInterval, price);

        return getMaxPrice(store, price);
    }

    function _storeMinMax(OracleStore store, uint updateInterval, uint price) internal {
        OracleStore.SlotSeed memory seed = store.getLatestSeed();

        if (price == 0) revert OracleLogic__NonZeroPrice();

        uint8 slot = uint8(block.timestamp / updateInterval % SLOT_COUNT);
        uint storedSlot = store.slot();

        store.setLatestUpdate(OracleStore.SlotSeed({price: price, blockNumber: block.number, timestamp: block.timestamp}));

        uint max = store.slotMax(slot);

        if (slot == storedSlot) {
            if (price > max) {
                store.setSlotMax(slot, price);
            } else if (price < store.slotMin(slot)) {
                store.setSlotMin(slot, price);
            }
        } else {
            store.setSlot(slot);

            store.setSlotMin(slot, price);
            store.setMedianMin(_getMedian(store.getSlotArrMin()));

            store.setSlotMax(slot, price);
            store.setMedianMax(_getMedian(store.getSlotArrMax()));

            // in case previous slots are outdated, we need to update them with the current price
            uint timeDelta = block.timestamp - seed.timestamp;
            uint delayedUpdateCount = timeDelta > updateInterval ? Math.min(timeDelta / updateInterval, 6) : 0;

            if (delayedUpdateCount > 0) {
                for (uint8 i = 0; i <= delayedUpdateCount; i++) {
                    uint8 prevSlot = (slot + SLOT_COUNT - i) % SLOT_COUNT;

                    if (price > store.slotMax(prevSlot)) {
                        store.setSlotMax(prevSlot, price);
                    } else if (price < store.slotMin(prevSlot)) {
                        store.setSlotMin(prevSlot, price);
                    }
                }

                emit OracleLogic__SyncDelayedSlot(updateInterval, seed.timestamp, block.timestamp, delayedUpdateCount, price);
            }

            emit OracleLogic__SlotSettled(updateInterval, seed.timestamp, seed.price, max);
        }

        emit OracleLogic__PriceUpdate(block.timestamp, price);
    }

    function _getMedian(uint[7] memory arr) internal pure returns (uint) {
        for (uint i = 1; i < 7; i++) {
            uint ix = arr[i];
            uint j = i;
            while (j > 0 && arr[j - 1] > ix) {
                arr[j] = arr[j - 1]; // Shift elements upwards to make room for ix
                j--;
            }
            arr[j] = ix; // Insert ix into its correct position
        }

        return arr[3]; // The median is at index 3 in 7 fixed size array
    }

    error OracleLogic__NotEnoughSources();
    error OracleLogic__NonZeroPrice();
}
