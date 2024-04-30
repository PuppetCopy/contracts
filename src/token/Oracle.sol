// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IVault} from "@balancer-labs/v2-interfaces/vault/IVault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/interfaces/IUniswapV3Pool.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

import {IAuthority} from "./../utils/interfaces/IAuthority.sol";
import {Permission} from "./../utils/auth/Permission.sol";

import {UniV3Prelude} from "../utils/UniV3Prelude.sol";

import {OracleStore, SLOT_COUNT} from "./store/OracleStore.sol";

contract Oracle is Permission, EIP712, ReentrancyGuard {
    event Oracle__SetConfig(uint timestmap, CallConfig callConfig, SecondaryPriceConfig[] exchangePriceSourceList);
    event Oracle__SyncDelayedSlot(uint updateInterval, uint seedTimestamp, uint currentTimestamp, uint delayedUpdateCount, uint price);
    event Oracle__SlotSettled(uint updateInterval, uint seedTimestamp, uint seedPrice, uint maxPrice);
    event Oracle__PriceUpdate(uint timestamp, uint price);

    struct SecondaryPriceConfig {
        bool enabled;
        IUniswapV3Pool[] sourceList;
        uint32 twapInterval;
        uint8 token1Deicmals;
    }

    struct CallConfig {
        IERC20 token;
        IVault vault;
        bytes32 poolId;
        uint updateInterval;
    }

    OracleStore store;
    CallConfig callConfig;
    mapping(IERC20 token => SecondaryPriceConfig) secondarySourceConfigMap;

    function getMaxPrice(IERC20 token) public view returns (uint) {
        return getMaxPrice(token, getPrimaryPoolPrice());
    }

    function getMinPrice(IERC20 token) public view returns (uint) {
        return getMinPrice(token, getPrimaryPoolPrice());
    }

    function getMaxPrice(IERC20 token, uint poolPrice) public view returns (uint) {
        uint maxPrimaryPrice = Math.max(store.medianMax(), poolPrice);
        if (callConfig.token == token) {
            return maxPrimaryPrice;
        }

        return getSecondaryPrice(token, maxPrimaryPrice);
    }

    function getMinPrice(IERC20 token, uint poolPrice) public view returns (uint) {
        uint minPrimaryPrice = Math.min(store.medianMin(), poolPrice);
        if (callConfig.token == token) {
            return minPrimaryPrice;
        }

        return getSecondaryPrice(token, minPrimaryPrice);
    }

    function getSecondaryPrice(IERC20 token, uint primaryPrice) public view returns (uint usdPerToken) {
        uint secondaryPrice = getSecondaryPoolPrice(token);

        usdPerToken = (secondaryPrice * primaryPrice) / 1e18;
    }

    function getSecondaryPrice(IERC20 token) external view returns (uint usdPerToken) {
        return getSecondaryPrice(token, getPrimaryPoolPrice());
    }

    function getPrimaryPoolPrice() public view returns (uint price) {
        (, uint[] memory balances,) = callConfig.vault.getPoolTokens(callConfig.poolId);

        uint tokenBalance = balances[1];
        uint primaryBalance = balances[0];

        uint balanceRatio = (primaryBalance * 1e18 * 80) / (tokenBalance * 20);
        price = balanceRatio;

        if (price == 0) revert Oracle__NonZeroPrice();
    }

    function getSecondaryPoolPrice(IERC20 token) public view returns (uint usdPerToken) {
        SecondaryPriceConfig memory tokenPerWntConfig = secondarySourceConfigMap[token];

        if (tokenPerWntConfig.enabled == false) revert Oracle__UnavailableSecondaryPrice();

        uint secondaryPrice = getSecondaryTwapMedianPrice(tokenPerWntConfig.sourceList, tokenPerWntConfig.twapInterval);

        usdPerToken = secondaryPrice;
    }

    function getSecondaryTwapMedianPrice(IUniswapV3Pool[] memory sourceList, uint32 twapInterval) public view returns (uint medianPrice) {
        uint sourceListLength = sourceList.length;
        if (sourceListLength < 3) revert Oracle__NotEnoughSources();

        uint[] memory priceList = new uint[](sourceListLength);

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

        uint medianIndex = (sourceListLength - 1) / 2; // Index of the median after the array is sorted
        medianPrice = priceList[medianIndex];
    }

    constructor(
        IAuthority _authority,
        OracleStore _store,
        CallConfig memory _callConfig,
        IERC20[] memory _tokenList,
        SecondaryPriceConfig[] memory _secondaryPriceConfigList
    ) Permission(_authority) EIP712("Oracle", "1") {
        store = _store;
        _setConfig(_callConfig, _tokenList, _secondaryPriceConfigList);
    }

    // governance

    function setConfig(
        CallConfig memory _callConfig, //
        IERC20[] memory _tokenList,
        SecondaryPriceConfig[] memory _secondaryPriceConfigList
    ) external auth {
        if (_callConfig.poolId == bytes32(0)) revert Oracle__InvalidPoolId();

        _setConfig(_callConfig, _tokenList, _secondaryPriceConfigList);
    }

    // internal

    function _setConfig(
        CallConfig memory _callConfig, //
        IERC20[] memory _tokenList,
        SecondaryPriceConfig[] memory _secondaryPriceConfigList
    ) internal {
        callConfig = _callConfig;

        if (_tokenList.length != _secondaryPriceConfigList.length) revert Oracle__TokenSourceListLengthMismatch();

        for (uint i; i < _secondaryPriceConfigList.length; i++) {
            SecondaryPriceConfig memory _config = _secondaryPriceConfigList[i];
            if (_config.sourceList.length % 2 == 0) revert Oracle__SourceCountNotOdd();
            if (_config.sourceList.length < 3) revert Oracle__NotEnoughSources();

            secondarySourceConfigMap[_tokenList[i]] = _config;
        }

        emit Oracle__SetConfig(block.timestamp, _callConfig, _secondaryPriceConfigList);
    }

    // state

    function setPrimaryPrice() external auth nonReentrant returns (uint) {
        uint currentPrice = getPrimaryPoolPrice();

        OracleStore.SeedSlot memory seed = store.getLatestSeed();

        if (seed.blockNumber == block.number && seed.price > currentPrice) {
            return seed.price;
        }

        setPrimaryMinMax(currentPrice);

        return currentPrice;
    }

    function setPrimaryMinMax(uint price) internal {
        OracleStore _store = store;
        OracleStore.SeedSlot memory seed = store.getLatestSeed();

        if (price == 0) revert Oracle__NonZeroPrice();

        uint8 slot = uint8(block.timestamp / callConfig.updateInterval % SLOT_COUNT);
        uint storedSlot = _store.slot();

        _store.setLatestSeed(OracleStore.SeedSlot({price: price, blockNumber: block.number, timestamp: block.timestamp}));

        uint max = _store.slotMax(slot);

        if (slot == storedSlot) {
            if (price > max) {
                _store.setSlotMax(slot, price);
            } else if (price < _store.slotMin(slot)) {
                _store.setSlotMin(slot, price);
            }
        } else {
            _store.setSlot(slot);

            _store.setSlotMin(slot, price);
            _store.setMedianMin(_getMedian(_store.getSlotArrMin()));

            _store.setSlotMax(slot, price);
            _store.setMedianMax(_getMedian(_store.getSlotArrMax()));

            // in case previous slots are outdated, we need to update them with the current price
            uint timeDelta = block.timestamp - seed.timestamp;
            uint delayedUpdateCount = timeDelta > callConfig.updateInterval ? Math.min(timeDelta / callConfig.updateInterval, 6) : 0;

            if (delayedUpdateCount > 0) {
                for (uint8 i = 0; i <= delayedUpdateCount; i++) {
                    uint8 prevSlot = (slot + SLOT_COUNT - i) % SLOT_COUNT;

                    if (price > _store.slotMax(prevSlot)) {
                        _store.setSlotMax(prevSlot, price);
                    } else if (price < _store.slotMin(prevSlot)) {
                        _store.setSlotMin(prevSlot, price);
                    }
                }

                emit Oracle__SyncDelayedSlot(callConfig.updateInterval, seed.timestamp, block.timestamp, delayedUpdateCount, price);
            }

            emit Oracle__SlotSettled(callConfig.updateInterval, seed.timestamp, seed.price, max);
        }

        emit Oracle__PriceUpdate(block.timestamp, price);
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

    error Oracle__InvalidPoolId();
    error Oracle__SourceCountNotOdd();
    error Oracle__NotEnoughSources();
    error Oracle__TokenSourceListLengthMismatch();
    error Oracle__NonZeroPrice();
    error Oracle__UnavailableSecondaryPrice();
}
