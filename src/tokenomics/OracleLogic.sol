// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/interfaces/IUniswapV3Pool.sol";
import {IVault} from "@balancer-labs/v2-interfaces/vault/IVault.sol";

import {OracleStore, SLOT_COUNT} from "./store/OracleStore.sol";
import {Math} from "./../utils/Math.sol";
import {UniV3Prelude} from "./../utils/UniV3Prelude.sol";

/**
 * @title OracleStore
 * @dev This contract mitigates price manipulation by:
 *
 * 1. Storing prices in seven different time slots to record the highest and lowest prices.
 * 2. Using the median of the highest slot prices as a reference to filter out outliers of of extreme values.
 * 3. Comparing the latest price with the median slot high and using the greater of the two to safeguard against undervaluation.
 * 4. Checking for price updates within the same block to protect against flash loan attacks that could temporarily distort prices.
 */
contract OracleLogic is Auth {
    event OracleLogic__PriceUpdate(uint timestamp, uint price);
    event OracleLogic__SlotSettled(uint updateInterval, uint timestamp, uint minPrice, uint maxPrice);
    event OracleLogic__SyncDelayedSlot(uint updateInterval, uint seedTimestamp, uint blockTimestamp, uint delayCount, uint price);

    constructor(Authority _authority) Auth(address(0), _authority) {}

    function getMaxPrice(OracleStore store, uint exchangeRate) public view returns (uint) {
        return Math.max(store.medianMax(), exchangeRate);
    }

    function getMinPrice(OracleStore store, uint exchangeRate) public view returns (uint) {
        return Math.min(store.medianMin(), exchangeRate);
    }

    function getPuppetPriceInWnt(IVault vault, bytes32 poolId) public view returns (uint price) {
        return _getPuppetExchangeRate(vault, poolId);
    }

    function getPuppetExchangeRateInUsdc(IUniswapV3Pool[] calldata wntUsdSourceList, IVault vault, bytes32 poolId, uint32 twapInterval)
        public
        view
        returns (uint)
    {
        uint usdPerWnt = getMedianWntPriceInUsd(wntUsdSourceList, twapInterval);
        uint puppetPerWnt = getPuppetPriceInWnt(vault, poolId);
        return usdPerWnt * 1e30 / puppetPerWnt;
    }

    function getMedianWntPriceInUsd(IUniswapV3Pool[] calldata wntUsdSourceList, uint32 twapInterval) public view returns (uint medianPrice) {
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

        medianPrice = priceList[medianIndex];
    }

    // state

    function syncTokenPrice(IUniswapV3Pool[] calldata wntUsdSourceList, IVault vault, OracleStore store, bytes32 poolId, uint32 twapInterval)
        external
        requiresAuth
        returns (uint)
    {
        uint price = getPuppetExchangeRateInUsdc(wntUsdSourceList, vault, poolId, twapInterval);
        OracleStore.SlotSeed memory seed = store.getLatestSeed();

        uint settledPrice = storeMinMax(store, seed, price);

        // the following tries to mitigate flashloan and DDOS attacks
        // -- Flashloan
        // assuming attacker tries to flashloan a low price to affect the price
        // low price settlment manipulation would be mitigated by taking previous higher settled price within the same block
        // - DDOS
        // settlment has to be below Acceptable Price check can an attacker prevent other tx's from being settled?
        // there doesn't seem to have an ecnonomical sense but it could be a case
        if (seed.blockNumber == block.number) {
            uint prevLatest = seed.price;

            if (prevLatest > price) {
                return prevLatest;
            }
        }

        return getMaxPrice(store, settledPrice);
    }

    // Internal

    function storeMinMax(OracleStore store, OracleStore.SlotSeed memory seed, uint price) internal returns (uint) {
        if (price == 0) revert OracleLogic__NonZeroPrice();

        uint8 slot = uint8(block.timestamp / seed.updateInterval % SLOT_COUNT);
        uint storedSlot = store.slot();

        store.setLatestUpdate(
            OracleStore.SlotSeed({price: price, blockNumber: block.number, timestamp: block.timestamp, updateInterval: seed.updateInterval})
        );

        uint max = store.slotMax(slot);

        if (slot == storedSlot) {
            if (price > max) {
                store.setSlotMax(slot, price);
            } else if (price < store.slotMin(slot)) {
                store.setSlotMin(slot, price);
            }
        } else {
            uint prevMin = store.slotMin(slot);
            store.setSlot(slot);

            store.setSlotMin(slot, price);
            store.setMedianMin(_getMedian(store.getSlotArrMin()));

            store.setSlotMax(slot, price);
            store.setMedianMax(_getMedian(store.getSlotArrMax()));

            // in case previous slots are outdated, we need to update them with the current price
            uint timeDelta = block.timestamp - seed.timestamp;
            uint delayedUpdateCount = timeDelta > seed.updateInterval ? Math.min(timeDelta / seed.updateInterval, 6) : 0;

            if (delayedUpdateCount > 0) {
                for (uint8 i = 0; i <= delayedUpdateCount; i++) {
                    uint8 prevSlot = (slot + SLOT_COUNT - i) % SLOT_COUNT;

                    if (price > store.slotMax(prevSlot)) {
                        store.setSlotMax(prevSlot, price);
                    } else if (price < store.slotMin(prevSlot)) {
                        store.setSlotMin(prevSlot, price);
                    }
                }

                emit OracleLogic__SyncDelayedSlot(seed.updateInterval, seed.timestamp, block.timestamp, delayedUpdateCount, price);
            }

            emit OracleLogic__SlotSettled(seed.updateInterval, seed.timestamp, prevMin, max);
        }

        emit OracleLogic__PriceUpdate(block.timestamp, price);

        return price;
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

    // returns price of puppet token in wnt with 30d precision
    function _getPuppetExchangeRate(IVault vault, bytes32 poolId) internal view returns (uint) {
        (, uint[] memory balances,) = vault.getPoolTokens(poolId);

        uint puppetBalance = balances[0];
        uint nSlotBalance = balances[1];
        uint precision = 10 ** 30;

        uint balanceRatio = (puppetBalance * 80 * precision) / (nSlotBalance * 20);
        uint price = balanceRatio;

        if (price == 0) revert OracleLogic__NonZeroPrice();

        return price;
    }

    // governance

    function setUpdateInterval(OracleStore store, uint updateInterval) external requiresAuth {
        require(updateInterval > 0, "update interval must be greater than 0");

        store.setSeedUpdateInterval(updateInterval);
    }

    error OracleLogic__NotEnoughSources();
    error OracleLogic__NonZeroPrice();
}
