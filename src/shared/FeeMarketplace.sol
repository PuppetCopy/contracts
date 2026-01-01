// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {PuppetToken} from "../tokenomics/PuppetToken.sol";
import {CoreContract} from "../utils/CoreContract.sol";
import {Error} from "../utils/Error.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {FeeMarketplaceStore} from "./FeeMarketplaceStore.sol";

/// @title FeeMarketplace
/// @notice Dutch auction for protocol fees - fees unlock over time, ask price decays until redeemed
/// @dev Two curves: (1) fees unlock linearly, (2) ask price decays linearly
///      Price discovery via time-decay auction
contract FeeMarketplace is CoreContract {
    struct Config {
        uint transferOutGasLimit;
        uint unlockTimeframe;
        uint askDecayTimeframe;
        uint askStart;
    }

    PuppetToken public immutable protocolToken;
    FeeMarketplaceStore public immutable store;

    mapping(IERC20 => uint) public accountedBalanceMap;
    mapping(IERC20 => uint) public unlockedFeesMap;
    mapping(IERC20 => uint) public lastUnlockTimestampMap;
    mapping(IERC20 => uint) public lastAskResetTimestampMap;

    Config public config;

    constructor(IAuthority _authority, PuppetToken _protocolToken, FeeMarketplaceStore _store, Config memory _config)
        CoreContract(_authority, abi.encode(_config))
    {
        protocolToken = _protocolToken;
        store = _store;
    }

    function getConfig() external view returns (Config memory) {
        return config;
    }

    function getPendingUnlock(IERC20 _feeToken) public view returns (uint) {
        uint _accounted = accountedBalanceMap[_feeToken];
        uint _unlocked = unlockedFeesMap[_feeToken];
        if (_accounted <= _unlocked) return 0;

        uint _locked = _accounted - _unlocked;
        uint _lastTimestamp = lastUnlockTimestampMap[_feeToken];
        if (_lastTimestamp == 0) return 0;

        uint _elapsed = block.timestamp - _lastTimestamp;
        uint _unlockedAmount = Math.mulDiv(_locked, _elapsed, config.unlockTimeframe);
        return Math.min(_unlockedAmount, _locked);
    }

    function getUnlockedBalance(IERC20 _feeToken) external view returns (uint) {
        return unlockedFeesMap[_feeToken] + getPendingUnlock(_feeToken);
    }

    function getAskPrice(IERC20 _feeToken) public view returns (uint) {
        uint _lastReset = lastAskResetTimestampMap[_feeToken];
        if (_lastReset == 0) return config.askStart;

        uint _elapsed = block.timestamp - _lastReset;
        if (_elapsed >= config.askDecayTimeframe) return 0;

        uint _decay = Math.mulDiv(config.askStart, _elapsed, config.askDecayTimeframe);
        return config.askStart - _decay;
    }

    function deposit(IERC20 _feeToken, address _depositor, uint _amount) external auth {
        if (_amount == 0) revert Error.FeeMarketplace__ZeroDeposit();

        _syncUnlock(_feeToken);

        if (accountedBalanceMap[_feeToken] == 0 && unlockedFeesMap[_feeToken] == 0) {
            lastAskResetTimestampMap[_feeToken] = block.timestamp;
        }

        store.transferIn(_feeToken, _depositor, _amount);
        accountedBalanceMap[_feeToken] += _amount;

        _logEvent("Deposit", abi.encode(_feeToken, _depositor, _amount));
    }

    function recordTransferIn(IERC20 _feeToken) external auth {
        uint _unaccounted = store.recordTransferIn(_feeToken);
        if (_unaccounted == 0) revert Error.FeeMarketplace__ZeroDeposit();

        _syncUnlock(_feeToken);

        if (accountedBalanceMap[_feeToken] == 0 && unlockedFeesMap[_feeToken] == 0) {
            lastAskResetTimestampMap[_feeToken] = block.timestamp;
        }

        accountedBalanceMap[_feeToken] += _unaccounted;

        _logEvent("Deposit", abi.encode(_feeToken, address(0), _unaccounted));
    }

    function acceptOffer(IERC20 _feeToken, address _buyer, address _receiver, uint _minOut) external auth {
        _syncUnlock(_feeToken);

        uint _payout = unlockedFeesMap[_feeToken];
        if (_payout == 0) revert Error.FeeMarketplace__InsufficientUnlockedBalance(0);
        if (_payout < _minOut) revert Error.FeeMarketplace__InsufficientUnlockedBalance(_payout);

        uint _cost = getAskPrice(_feeToken);

        if (_cost > 0) {
            store.transferIn(protocolToken, _buyer, _cost);
            store.burn(_cost);
        }

        unlockedFeesMap[_feeToken] = 0;
        accountedBalanceMap[_feeToken] -= _payout;

        store.transferOut(config.transferOutGasLimit, _feeToken, _receiver, _payout);

        lastAskResetTimestampMap[_feeToken] = block.timestamp;

        _logEvent("AcceptOffer", abi.encode(_feeToken, _buyer, _receiver, _payout, _cost));
    }

    function _syncUnlock(IERC20 _feeToken) internal {
        uint _pending = getPendingUnlock(_feeToken);
        if (_pending > 0) {
            unlockedFeesMap[_feeToken] += _pending;
        }
        lastUnlockTimestampMap[_feeToken] = block.timestamp;
    }

    function _setConfig(bytes memory _data) internal override {
        Config memory _config = abi.decode(_data, (Config));

        if (_config.transferOutGasLimit == 0) revert Error.FeeMarketplace__InvalidConfig();
        if (_config.unlockTimeframe == 0) revert Error.FeeMarketplace__InvalidConfig();
        if (_config.askDecayTimeframe == 0) revert Error.FeeMarketplace__InvalidConfig();
        if (_config.askDecayTimeframe < _config.unlockTimeframe) revert Error.FeeMarketplace__InvalidConfig();
        if (_config.askStart == 0) revert Error.FeeMarketplace__InvalidConfig();

        config = _config;
    }
}
