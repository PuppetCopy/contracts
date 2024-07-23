// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IVault, IERC20 as IBalIERC20} from "@balancer-labs/v2-interfaces/vault/IVault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/interfaces/IUniswapV3Pool.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

import {IAuthority} from "./../utils/interfaces/IAuthority.sol";
import {Permission} from "./../utils/access/Permission.sol";
import {PoolUtils} from "../utils/PoolUtils.sol";

import {OracleStore, SLOT_COUNT} from "./store/OracleStore.sol";

contract Oracle is Permission, EIP712, ReentrancyGuard {
    event Oracle__SetConfig(uint timestmap, PrimaryPriceConfig primaryConfig, SecondaryPriceConfig[] exchangePriceSourceList);
    event Oracle__SyncDelayedSlot(uint updateInterval, uint seedTimestamp, uint currentTimestamp, uint delayedUpdateCount, uint price);
    event Oracle__SlotSettled(uint updateInterval, uint seedTimestamp, uint seedPrice);
    event Oracle__PriceUpdate(uint timestamp, uint price);

    struct SecondaryPriceConfig {
        bool enabled;
        IUniswapV3Pool[] sourceList;
        uint32 twapInterval;
        IERC20 token;
    }

    struct PrimaryPriceConfig {
        IERC20 token;
        IVault vault;
        bytes32 poolId;
        uint updateInterval;
    }

    OracleStore store;
    PrimaryPriceConfig primaryConfig;
    mapping(IERC20 token => SecondaryPriceConfig) secondarySourceConfigMap;

    function getMaxPrice(IERC20 token) public view returns (uint) {
        return getMaxPrice(token, getPrimaryPoolPrice());
    }

    function getMinPrice(IERC20 token) public view returns (uint) {
        return getMinPrice(token, getPrimaryPoolPrice());
    }

    function getMaxPrice(IERC20 token, uint poolPrice) public view returns (uint) {
        uint maxPrimaryPrice = Math.max(store.medianMax(), poolPrice);
        if (primaryConfig.token == token) {
            return maxPrimaryPrice;
        }

        return getSecondaryPrice(token, maxPrimaryPrice);
    }

    function getMinPrice(IERC20 token, uint poolPrice) public view returns (uint) {
        uint minPrimaryPrice = Math.min(store.medianMin(), poolPrice);
        if (primaryConfig.token == token) {
            return minPrimaryPrice;
        }

        return getSecondaryPrice(token, minPrimaryPrice);
    }

    function getSecondaryPrice(IERC20 token, uint primaryPrice) public view returns (uint usdPerToken) {
        uint secondaryPrice = getSecondaryPoolPrice(token);

        usdPerToken = secondaryPrice * primaryPrice / 1e18;
    }

    function getSecondaryPrice(IERC20 token) external view returns (uint usdPerToken) {
        return getSecondaryPrice(token, getPrimaryPoolPrice());
    }

    function getPrimaryPoolPrice() public view returns (uint price) {
        (, uint[] memory balances,) = primaryConfig.vault.getPoolTokens(primaryConfig.poolId);

        // price = (balances[0] * 80e18) / (balances[1] * 20); // token/wnt
        price = (balances[0] * 80e18) / (balances[1] * 20); // wnt/token

        if (price == 0) revert Oracle__NonZeroPrice();
    }

    function getSecondaryPoolPrice(IERC20 token) public view returns (uint) {
        SecondaryPriceConfig memory tokenPerWntConfig = secondarySourceConfigMap[token];

        if (tokenPerWntConfig.enabled == false) revert Oracle__UnavailableSecondaryPrice();

        if (tokenPerWntConfig.sourceList.length == 1) {
            return PoolUtils.getTwapPrice(tokenPerWntConfig.sourceList[0], 18, tokenPerWntConfig.twapInterval);
        }

        return PoolUtils.getTwapMedianPrice(tokenPerWntConfig.sourceList, tokenPerWntConfig.twapInterval);
    }

    constructor(
        IAuthority _authority,
        OracleStore _store,
        PrimaryPriceConfig memory _primaryPriceConfig,
        SecondaryPriceConfig[] memory _secondaryPriceConfigList
    ) Permission(_authority) EIP712("Oracle", "1") {
        store = _store;
        _setConfig(_primaryPriceConfig, _secondaryPriceConfigList);
    }

    // governance

    function setConfig(
        PrimaryPriceConfig memory _primaryPriceConfig, //
        SecondaryPriceConfig[] memory _secondaryPriceConfigList
    ) external auth {
        if (_primaryPriceConfig.poolId == bytes32(0)) revert Oracle__InvalidPoolId();

        _setConfig(_primaryPriceConfig, _secondaryPriceConfigList);
    }

    // internal

    function _setConfig(
        PrimaryPriceConfig memory _primaryPriceConfig, //
        SecondaryPriceConfig[] memory _secondaryPriceConfigList
    ) internal {
        (IBalIERC20[] memory _tokens,,) = _primaryPriceConfig.vault.getPoolTokens(_primaryPriceConfig.poolId);

        address _primaryTokenAddress = address(_primaryPriceConfig.token);

        if (address(_tokens[0]) != _primaryTokenAddress && address(_tokens[1]) != _primaryTokenAddress) revert Oracle__MisconfiguredPrimaryPool();

        for (uint i; i < _secondaryPriceConfigList.length; i++) {
            SecondaryPriceConfig memory _config = _secondaryPriceConfigList[i];

            if (_config.sourceList.length % 2 == 0) revert Oracle__MisconfiguredSecondaryPool();

            // validate secondary pool sources
            for (uint j; j < _config.sourceList.length; j++) {
                if (
                    _config.sourceList[j].token0() != _primaryTokenAddress && _config.sourceList[j].token1() != _primaryTokenAddress
                        || _config.sourceList[j].token0() != address(_config.token) && _config.sourceList[j].token1() != address(_config.token)
                ) {
                    revert Oracle__MisconfiguredSecondaryPool();
                }
            }

            secondarySourceConfigMap[_config.token] = _config;
        }

        primaryConfig = _primaryPriceConfig;

        emit Oracle__SetConfig(block.timestamp, _primaryPriceConfig, _secondaryPriceConfigList);
    }

    // state

    function setPrimaryPrice() external auth nonReentrant returns (uint) {
        uint currentPrice = getPrimaryPoolPrice();
        IVault.UserBalanceOp[] memory noop = new IVault.UserBalanceOp[](0);
        primaryConfig.vault.manageUserBalance(noop);

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

        uint8 slot = uint8(block.timestamp / primaryConfig.updateInterval % SLOT_COUNT);
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

            uint timeElapsed = block.timestamp - seed.timestamp;

            if (timeElapsed > primaryConfig.updateInterval) {
                uint delayedSlotCount = Math.min(timeElapsed / primaryConfig.updateInterval, 6);
                for (uint8 i = 0; i <= delayedSlotCount; i++) {
                    uint8 prevSlot = (slot + SLOT_COUNT - i) % SLOT_COUNT;

                    _store.setSlotMax(prevSlot, price);
                    _store.setSlotMin(prevSlot, price);
                }

                emit Oracle__SyncDelayedSlot(primaryConfig.updateInterval, seed.timestamp, block.timestamp, delayedSlotCount, price);
            }

            emit Oracle__SlotSettled(primaryConfig.updateInterval, seed.timestamp, seed.price);
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
    error Oracle__TokenSourceListLengthMismatch();
    error Oracle__NonZeroPrice();
    error Oracle__UnavailableSecondaryPrice();
    error Oracle__MisconfiguredPrimaryPool();
    error Oracle__MisconfiguredSecondaryPool();
}
