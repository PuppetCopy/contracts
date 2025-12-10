// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.31;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {PuppetToken} from "../tokenomics/PuppetToken.sol";
import {CoreContract} from "../utils/CoreContract.sol";
import {Error} from "../utils/Error.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {FeeMarketplaceStore} from "./FeeMarketplaceStore.sol";

/**
 * @notice Marketplace for trading accumulated protocol fees with protocol tokens at fixed prices
 * @dev Fee tokens unlock gradually over `distributionTimeframe`. New deposits dilute the unlock rate
 *      of existing locked tokens, limiting arbitrage opportunities during high deposit activity.
 */
contract FeeMarketplace is CoreContract {
    struct Config {
        uint transferOutGasLimit;
        uint distributionTimeframe;
    }

    PuppetToken public immutable protocolToken;
    FeeMarketplaceStore public immutable store;

    mapping(IERC20 => uint) public askAmount;
    mapping(IERC20 => uint) public unclockedFees;
    mapping(IERC20 => uint) public lastDistributionTimestamp;
    mapping(IERC20 => uint) public accountedBalance;

    Config config;

    constructor(
        IAuthority _authority,
        PuppetToken _protocolToken,
        FeeMarketplaceStore _store,
        Config memory _config
    ) CoreContract(_authority, abi.encode(_config)) {
        protocolToken = _protocolToken;
        store = _store;
    }

    /**
     * @notice Get current configuration parameters
     */
    function getConfig() external view returns (Config memory) {
        return config;
    }

    /**
     * @notice Calculate pending unlocked amount for a fee token based on elapsed time
     */
    function getPendingUnlock(
        IERC20 _feeToken
    ) public view returns (uint _pending) {
        uint _accountedBalance = accountedBalance[_feeToken];
        uint _unlockedAmount = unclockedFees[_feeToken];

        if (_accountedBalance <= _unlockedAmount) return 0;

        uint _lockedAmount = _accountedBalance - _unlockedAmount;
        uint _timeElapsed = block.timestamp - lastDistributionTimestamp[_feeToken];

        _pending = Math.min((_lockedAmount * _timeElapsed) / config.distributionTimeframe, _lockedAmount);
    }

    /**
     * @notice Get total unlocked balance available for redemption
     */
    function getTotalUnlocked(
        IERC20 _feeToken
    ) public view returns (uint) {
        return unclockedFees[_feeToken] + getPendingUnlock(_feeToken);
    }

    /**
     * @notice Deposit fee tokens into the marketplace
     */
    function deposit(
        IERC20 _feeToken,
        address _depositor,
        uint _amount
    ) external auth {
        require(_amount > 0, Error.FeeMarketplace__ZeroDeposit());

        _updateUnlockedBalance(_feeToken);

        store.transferIn(_feeToken, _depositor, _amount);
        accountedBalance[_feeToken] += _amount;

        _logEvent("Deposit", abi.encode(_feeToken, _depositor, _amount));
    }

    /**
     * @notice Sync unaccounted tokens that were transferred directly to store
     */
    function syncBalance(
        IERC20 _feeToken
    ) external auth {
        _updateUnlockedBalance(_feeToken);

        uint _unaccountedAmount = store.recordTransferIn(_feeToken);
        require(_unaccountedAmount > 0, Error.FeeMarketplace__ZeroDeposit());

        accountedBalance[_feeToken] += _unaccountedAmount;

        _logEvent("Deposit", abi.encode(_feeToken, address(0), _unaccountedAmount));
    }

    /**
     * @notice Execute fee redemption at fixed ask price
     * @dev Burns protocol tokens received
     */
    function acceptOffer(
        IERC20 _feeToken,
        address _depositor,
        address _receiver,
        uint _purchaseAmount
    ) external auth {
        require(_purchaseAmount > 0, Error.FeeMarketplace__InvalidAmount());

        uint _currentAskAmount = askAmount[_feeToken];

        require(_currentAskAmount > 0, Error.FeeMarketplace__NotAuctionableToken());

        // Update the fee token's unlocked balance before redemption.
        _updateUnlockedBalance(_feeToken);

        uint _accruedFees = unclockedFees[_feeToken];
        require(_accruedFees >= _purchaseAmount, Error.FeeMarketplace__InsufficientUnlockedBalance(_accruedFees));

        store.transferIn(protocolToken, _depositor, _currentAskAmount);
        store.burn(_currentAskAmount);

        unclockedFees[_feeToken] -= _purchaseAmount;
        accountedBalance[_feeToken] -= _purchaseAmount;
        store.transferOut(config.transferOutGasLimit, _feeToken, _receiver, _purchaseAmount);

        _logEvent("AcceptOffer", abi.encode(_feeToken, _receiver, _purchaseAmount, _currentAskAmount));
    }

    /**
     * @notice Set fixed redemption price for a fee token
     */
    function setAskPrice(
        IERC20 _feeToken,
        uint _amount
    ) external auth {
        askAmount[_feeToken] = _amount;
        _logEvent("SetAskAmount", abi.encode(_feeToken, _amount));
    }

    function _updateUnlockedBalance(
        IERC20 _feeToken
    ) internal {
        uint _pendingUnlock = getPendingUnlock(_feeToken);
        if (_pendingUnlock > 0) {
            unclockedFees[_feeToken] += _pendingUnlock;
        }
        lastDistributionTimestamp[_feeToken] = block.timestamp;
    }

    function _setConfig(
        bytes memory _data
    ) internal override {
        Config memory _config = abi.decode(_data, (Config));

        require(_config.transferOutGasLimit > 0 && _config.distributionTimeframe > 0);

        config = _config;
    }
}
