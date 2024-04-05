// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IVault} from "@balancer-labs/v2-interfaces/vault/IVault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {OracleStore} from "./tokenomics/store/OracleStore.sol";
import {OracleLogic} from "./tokenomics/logic/OracleLogic.sol";

contract Oracle is Auth, ReentrancyGuard {
    event RewardRouter__SetConfig(uint timestmap, CallConfig callConfig, OracleLogic.ExchangePriceSourceConfig[] exchangePriceSourceList);

    struct CallConfig {
        OracleStore store;
        IVault vault;
        IERC20 wnt;
        bytes32 poolId;
        uint updateInterval;
    }

    CallConfig callConfig;

    mapping(IERC20 token => OracleLogic.ExchangePriceSourceConfig) tokenPerWntConfigMap;

    constructor(
        Authority _authority,
        CallConfig memory _callConfig,
        IERC20[] memory _tokenList,
        OracleLogic.ExchangePriceSourceConfig[] memory _exchangePriceSourceList
    ) Auth(address(0), _authority) {
        _setConfig(_callConfig, _tokenList, _exchangePriceSourceList);
    }

    function getPoolPrice() public view returns (uint) {
        return OracleLogic.getPoolPrice(callConfig.vault, callConfig.poolId);
    }

    function getMaxPrice() public view returns (uint) {
        return OracleLogic.getMaxPrice(callConfig.store, callConfig.vault, callConfig.poolId);
    }

    function getMinPrice() public view returns (uint) {
        return OracleLogic.getMinPrice(callConfig.store, callConfig.vault, callConfig.poolId);
    }

    function getMaxPriceInToken(IERC20 token) public view returns (uint) {
        if (token == callConfig.wnt) return getMaxPrice();

        return OracleLogic.getMaxPriceInToken(callConfig.store, callConfig.vault, tokenPerWntConfigMap[token], callConfig.poolId);
    }

    function getMinPriceInToken(IERC20 token) public view returns (uint) {
        if (token == callConfig.wnt) return getMinPrice();

        return OracleLogic.getMinPriceInToken(callConfig.store, callConfig.vault, tokenPerWntConfigMap[token], callConfig.poolId);
    }

    function storePrice() public requiresAuth nonReentrant {
        OracleLogic.storePrice(callConfig.store, callConfig.vault, callConfig.poolId, callConfig.updateInterval);
    }

    // governance

    function setConfig(
        CallConfig memory _callConfig,
        IERC20[] memory _tokenList,
        OracleLogic.ExchangePriceSourceConfig[] memory _exchangePriceSourceList
    ) external requiresAuth {
        if (_callConfig.poolId == bytes32(0)) revert Oracle__InvalidPoolId();

        _setConfig(_callConfig, _tokenList, _exchangePriceSourceList);
    }

    // internal

    function _setConfig(
        CallConfig memory _callConfig,
        IERC20[] memory _tokenList,
        OracleLogic.ExchangePriceSourceConfig[] memory _exchangePriceSourceList
    ) internal {
        callConfig = _callConfig;

        if (_tokenList.length != _exchangePriceSourceList.length) revert Oracle__TokenSourceListLengthMismatch();

        for (uint i; i < _exchangePriceSourceList.length; i++) {
            OracleLogic.ExchangePriceSourceConfig memory _config = _exchangePriceSourceList[i];
            if (_config.sourceList.length % 2 == 0) revert Oracle__SourceCountNotOdd();
            if (_config.sourceList.length < 3) revert Oracle__NotEnoughSources();

            tokenPerWntConfigMap[_tokenList[i]] = _config;
        }

        emit RewardRouter__SetConfig(block.timestamp, callConfig, _exchangePriceSourceList);
    }

    error Oracle__InvalidPoolId();
    error Oracle__SourceCountNotOdd();
    error Oracle__NotEnoughSources();
    error Oracle__TokenSourceListLengthMismatch();
}
