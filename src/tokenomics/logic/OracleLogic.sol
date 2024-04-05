// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IVault} from "@balancer-labs/v2-interfaces/vault/IVault.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/interfaces/IUniswapV3Pool.sol";

import {OracleStore, SLOT_COUNT} from "../store/OracleStore.sol";
import {UniV3Prelude} from "../../utils/UniV3Prelude.sol";

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
 * -- DDOS
 * settlment has to be below Acceptable Price check can an attacker prevent other tx's from being settled?
 * there doesn't seem to have an ecnonomical sense but it could be a case
 *
 */
library OracleLogic {
    event OracleLogic__SyncDelayedSlot(uint updateInterval, uint seedTimestamp, uint currentTimestamp, uint delayedUpdateCount, uint price);
    event OracleLogic__SlotSettled(uint updateInterval, uint seedTimestamp, uint seedPrice, uint maxPrice);
    event OracleLogic__PriceUpdate(uint timestamp, uint price);

    struct WntPriceConfig {
        bool enabled;
        IUniswapV3Pool[] sourceList;
        uint32 twapInterval;
        uint8 sourceTokenDeicmals;
    }

    function getMaxPrice(OracleStore store, IVault vault, bytes32 poolId) internal view returns (uint) {
        return Math.max(store.medianMax(), getVaultPriceInWnt(vault, poolId));
    }

    function getMinPrice(OracleStore store, IVault vault, bytes32 poolId) internal view returns (uint) {
        return Math.min(store.medianMin(), getVaultPriceInWnt(vault, poolId));
    }

    function getMaxPriceInToken(
        OracleStore store, //
        IVault vault,
        WntPriceConfig memory tokenPerWntConfig,
        bytes32 poolId
    ) internal view returns (uint usdPerToken) {
        uint sourceTokenPerWnt = getTokenPerWntUsingTwapMedian(tokenPerWntConfig.sourceList, tokenPerWntConfig.twapInterval);
        uint tokenPerWnt = getMaxPrice(store, vault, poolId);
        usdPerToken = sourceTokenPerWnt * 1e30 / tokenPerWnt;
    }

    function getMinPriceInToken(
        OracleStore store, //
        IVault vault,
        WntPriceConfig memory tokenPerWntConfig,
        bytes32 poolId
    ) internal view returns (uint usdPerToken) {
        uint denominator = 10 ** (18 + tokenPerWntConfig.sourceTokenDeicmals);

        uint sourceTokenPerWnt = getTokenPerWntUsingTwapMedian(tokenPerWntConfig.sourceList, tokenPerWntConfig.twapInterval) * denominator;
        uint tokenPerWnt = getMinPrice(store, vault, poolId);
        usdPerToken = sourceTokenPerWnt * 1e30 / tokenPerWnt;
    }

    function getVaultPriceInWnt(IVault vault, bytes32 poolId) internal view returns (uint price) {
        (, uint[] memory balances,) = vault.getPoolTokens(poolId);

        uint tokenBalance = balances[0];
        uint nSlotBalance = balances[1];
        uint precision = 10 ** 30;

        uint balanceRatio = (tokenBalance * 80 * precision) / (nSlotBalance * 20);
        price = balanceRatio;

        if (price == 0) revert OracleLogic__NonZeroPrice();
    }

    function getTokenPerWntUsingTwapMedian(IUniswapV3Pool[] memory sourceList, uint32 twapInterval) internal view returns (uint medianPrice) {
        uint sourceListLength = sourceList.length;
        if (sourceListLength < 3) revert OracleLogic__NotEnoughSources();

        uint[] memory priceList = new uint[](sourceListLength);
        uint medianIndex = (sourceListLength - 1) / 2; // Index of the median after the array is sorted

        // Initialize the first element
        priceList[0] = UniV3Prelude.getTwapPrice(sourceList[0], 18, twapInterval);

        for (uint i = 1; i < sourceListLength; i++) {
            uint currentPrice = UniV3Prelude.getTwapPrice(sourceList[i], 18, twapInterval);

            uint j = i;
            while (j > 0 && priceList[j - 1] > currentPrice) {
                priceList[j] = priceList[j - 1];
                j--;
            }
            priceList[j] = currentPrice;
        }

        medianPrice = priceList[medianIndex];
    }

    // state
    function storePrice(OracleStore store, IVault vault, bytes32 poolId, uint updateInterval) internal {
        uint price = getVaultPriceInWnt(vault, poolId);
        OracleStore.SlotSeed memory seed = store.getLatestSeed();

        if (seed.blockNumber == block.number && seed.price > price) {
            return;
        }

        storeMinMax(store, updateInterval, price);
    }

    function storeMinMax(OracleStore store, uint updateInterval, uint price) internal {
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
            store.setMedianMin(getMedian(store.getSlotArrMin()));

            store.setSlotMax(slot, price);
            store.setMedianMax(getMedian(store.getSlotArrMax()));

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

    function getMedian(uint[7] memory arr) internal pure returns (uint) {
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
