// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {PuppetToken} from "../tokenomics/PuppetToken.sol";
import {CoreContract} from "../utils/CoreContract.sol";
import {Error} from "../utils/Error.sol";
import {Precision} from "../utils/Precision.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {FeeMarketplaceStore} from "./FeeMarketplaceStore.sol";

/**
 * @notice Marketplace for trading accumulated protocol fees with protocol tokens at fixed prices
 * @dev Fee tokens unlock gradually over time. Each token has a fixed redemption price regardless of quantity.
 */
contract FeeMarketplace is CoreContract {
    struct Config {
        uint transferOutGasLimit;
        uint distributionTimeframe;
        uint burnBasisPoints;
    }

    PuppetToken public immutable protocolToken;
    FeeMarketplaceStore public immutable store;

    mapping(IERC20 => uint) public askAmount;
    mapping(IERC20 => uint) public unclockedFees;
    mapping(IERC20 => uint) public lastDistributionTimestamp;

    uint public distributionBalance;

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
        IERC20 feeToken
    ) public view returns (uint pending) {
        uint totalDeposited = store.getTokenBalance(feeToken);
        uint unlockedAmount = unclockedFees[feeToken];

        if (totalDeposited <= unlockedAmount) return 0;

        uint newDepositAmount = totalDeposited - unlockedAmount;
        uint timeElapsed = block.timestamp - lastDistributionTimestamp[feeToken];

        pending = Math.min((newDepositAmount * timeElapsed) / config.distributionTimeframe, newDepositAmount);
    }

    /**
     * @notice Get total unlocked balance available for redemption
     */
    function getTotalUnlocked(
        IERC20 feeToken
    ) public view returns (uint) {
        return unclockedFees[feeToken] + getPendingUnlock(feeToken);
    }

    /**
     * @notice Deposit fee tokens into the marketplace
     */
    function deposit(IERC20 _feeToken, address _depositor, uint _amount) external auth {
        require(_amount > 0, Error.FeeMarketplace__ZeroDeposit());

        _updateUnlockedBalance(_feeToken);

        store.transferIn(_feeToken, _depositor, _amount);

        _logEvent("Deposit", abi.encode(_feeToken, _amount));
    }

    /**
     * @notice Record unaccounted transferred tokens and sync internal accounting
     */
    function recordTransferIn(
        IERC20 _feeToken
    ) external auth returns (uint _amount) {
        _updateUnlockedBalance(_feeToken);

        _amount = store.recordTransferIn(_feeToken);
        require(_amount > 0, Error.FeeMarketplace__ZeroDeposit());

        _logEvent("Deposit", abi.encode(_feeToken, _amount));
    }

    /**
     * @notice Execute fee redemption at fixed ask price
     * @dev Burns portion of protocol tokens received based on config
     */
    function acceptOffer(IERC20 _feeToken, address _depositor, address _receiver, uint _purchaseAmount) external auth {
        uint _currentAskAmount = askAmount[_feeToken];

        require(_currentAskAmount > 0, Error.FeeMarketplace__NotAuctionableToken());

        // Update the fee token's unlocked balance before redemption.
        _updateUnlockedBalance(_feeToken);

        uint _accuredFees = unclockedFees[_feeToken];
        require(_accuredFees >= _purchaseAmount, Error.FeeMarketplace__InsufficientUnlockedBalance(_accuredFees));

        store.transferIn(protocolToken, _depositor, _currentAskAmount);

        uint _burnAmount;
        uint _distributeAmount = _currentAskAmount;
        if (config.burnBasisPoints > 0) {
            _burnAmount = Precision.applyBasisPoints(config.burnBasisPoints, _currentAskAmount);
            store.burn(_burnAmount);
            _distributeAmount -= _burnAmount;
        }

        distributionBalance += _distributeAmount;
        unclockedFees[_feeToken] -= _purchaseAmount;
        store.transferOut(config.transferOutGasLimit, _feeToken, _receiver, _purchaseAmount);

        _logEvent("AcceptOffer", abi.encode(_feeToken, _receiver, _purchaseAmount, _burnAmount, _distributeAmount));
    }

    /**
     * @notice Set fixed redemption price for a fee token
     */
    function setAskPrice(IERC20 _feeToken, uint _amount) external auth {
        askAmount[_feeToken] = _amount;
        _logEvent("SetAskAmount", abi.encode(_feeToken, _amount));
    }

    /**
     * @notice Transfer protocol tokens from distribution balance
     */
    function collectDistribution(address _receiver, uint _amount) external auth {
        require(_receiver != address(0), Error.FeeMarketplace__InvalidReceiver());
        require(_amount > 0, Error.FeeMarketplace__InvalidAmount());
        require(
            _amount <= distributionBalance,
            Error.FeeMarketplace__InsufficientDistributionBalance(_amount, distributionBalance)
        );

        distributionBalance -= _amount;
        store.transferOut(config.transferOutGasLimit, protocolToken, _receiver, _amount);
    }

    function _updateUnlockedBalance(
        IERC20 _feeToken
    ) internal {
        uint pendingUnlock = getPendingUnlock(_feeToken);
        if (pendingUnlock > 0) {
            unclockedFees[_feeToken] += pendingUnlock;
        }
        lastDistributionTimestamp[_feeToken] = block.timestamp;
    }

    function _setConfig(
        bytes memory _data
    ) internal override {
        Config memory _config = abi.decode(_data, (Config));

        require(_config.distributionTimeframe > 0, "FeeMarketplace: timeframe cannot be zero");
        require(
            _config.burnBasisPoints <= Precision.BASIS_POINT_DIVISOR, "FeeMarketplace: burn basis points exceeds 100%"
        );

        config = _config;
    }
}
