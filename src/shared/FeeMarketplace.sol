// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {PuppetToken} from "../tokenomics/PuppetToken.sol";
import {BankStore} from "../utils/BankStore.sol";
import {CoreContract} from "../utils/CoreContract.sol";
import {Error} from "../utils/Error.sol";
import {Precision} from "../utils/Precision.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {FeeMarketplaceStore} from "./FeeMarketplaceStore.sol";

/**
 * @title Fee Marketplace
 * @notice Publicly offers accumulated protocol fees for purchase in exchange for protocol tokens at fixed prices.
 *
 * @dev Core mechanics:
 * - Fee tokens unlock gradually over time after deposit
 * - Each fee token has a fixed redemption price (askAmount)
 * - Price applies to ANY quantity up to available balance
 * - Public can purchase all unlocked tokens at the posted price
 * - Protocol tokens received are burned/distributed per configuration
 *
 * @dev Example: If askAmount[USDC] = 1000 and there are 500 USDC unlocked:
 * - Taker paying 1000 protocol tokens redeems all 500 USDC
 * - If unlocked balance grows to 2000 USDC, same 1000 tokens now gets 2000 USDC
 * - Protocol publicly offers all unlocked tokens at this fixed price
 */
contract FeeMarketplace is CoreContract {
    /**
     * @param feeDistributor Receives non-burned protocol tokens
     * @param distributionTimeframe Unlock duration for deposits (seconds)
     * @param burnBasisPoints Protocol tokens to burn (basis points: 100 = 1%)
     */
    struct Config {
        BankStore feeDistributor;
        uint distributionTimeframe;
        uint burnBasisPoints;
    }

    /// @notice Holds fee tokens
    FeeMarketplaceStore public immutable store;

    /// @notice Protocol token used for purchases
    PuppetToken public immutable protocolToken;

    /// @notice Fixed price to redeem any amount of each fee token
    mapping(IERC20 => uint) public askAmount;

    /// @notice Currently unlocked balance per fee token
    mapping(IERC20 => uint) public accruedFee;

    /// @notice Last unlock calculation timestamp per fee token
    mapping(IERC20 => uint) public lastDistributionTimestamp;

    /// @notice Current marketplace settings
    Config public config;

    constructor(
        IAuthority _authority,
        PuppetToken _protocolToken,
        FeeMarketplaceStore _store,
        Config memory _config
    ) CoreContract(_authority) {
        store = _store;
        protocolToken = _protocolToken;

        _setInitConfig(abi.encode(_config));
    }

    /**
     * @notice Returns the pending unlocked amount for a fee token based on elapsed time.
     * @param feeToken The fee token.
     * @return pending The number of fee tokens that have newly unlocked.
     */
    function getPendingUnlock(
        IERC20 feeToken
    ) public view returns (uint pending) {
        uint totalDeposited = store.getTokenBalance(feeToken);
        uint alreadyUnlocked = accruedFee[feeToken];

        if (totalDeposited <= alreadyUnlocked) return 0;

        uint netNewDeposits = totalDeposited - alreadyUnlocked;
        uint timeElapsed = block.timestamp - lastDistributionTimestamp[feeToken];

        pending = Math.min((netNewDeposits * timeElapsed) / config.distributionTimeframe, netNewDeposits);
    }

    /**
     * @notice Returns the total fee balance that is available for redemption.
     * @param feeToken The fee token.
     * @return Total unlocked fee balance.
     */
    function getTotalUnlocked(
        IERC20 feeToken
    ) public view returns (uint) {
        return accruedFee[feeToken] + getPendingUnlock(feeToken);
    }

    /**
     * @notice Deposits fee tokens into the marketplace.
     * @param _feeToken The fee token to deposit.
     * @param _bank The BankStore to deposit the fee tokens into.
     * @param _amount The amount of fee tokens to deposit.
     */
    function deposit(IERC20 _feeToken, BankStore _bank, uint _amount) external auth {
        require(_amount > 0, Error.FeeMarketplace__ZeroDeposit());

        // Update the fee token's unlocked balance before processing the deposit.
        _updateUnlockedBalance(_feeToken);

        // Transfer fee tokens into the BankStore.
        store.interTransferIn(_feeToken, _bank, _amount);

        _logEvent("Deposit", abi.encode(_feeToken, _bank, _amount));
    }

    /**
     * @notice Executes a fee redemption offer.
     * @param _feeToken The fee token to be redeemed.
     * @param _depositor The address making the redemption.
     * @param _receiver The address receiving the fee tokens.
     * @param _purchaseAmount The amount of fee tokens to redeem.
     */
    function acceptOffer(IERC20 _feeToken, address _depositor, address _receiver, uint _purchaseAmount) external auth {
        uint _currentAskAmount = askAmount[_feeToken];

        require(_currentAskAmount > 0, Error.FeeMarketplace__NotAuctionableToken());

        // Update the fee token's unlocked balance before redemption.
        _updateUnlockedBalance(_feeToken);

        uint _accuredFees = accruedFee[_feeToken];
        require(_accuredFees >= _purchaseAmount, Error.FeeMarketplace__InsufficientUnlockedBalance(_accuredFees));

        // Calculate protocol token burn and reward amounts.
        uint _distributeAmount = _currentAskAmount;
        uint _burnAmount;

        store.transferIn(protocolToken, _depositor, _currentAskAmount);

        // Burn the designated portion of protocol tokens.
        if (config.burnBasisPoints > 0) {
            _burnAmount = Precision.applyBasisPoints(config.burnBasisPoints, _currentAskAmount);
            store.burn(_burnAmount);
            _distributeAmount -= _burnAmount;
        }

        // Transfer the remaining tokens to the reward distributor.
        if (_distributeAmount > 0 && address(config.feeDistributor) != address(0)) {
            config.feeDistributor.interTransferIn(protocolToken, store, _distributeAmount);
        }

        // Deduct the redeemed fee tokens from the unlocked balance.
        accruedFee[_feeToken] = _accuredFees - _purchaseAmount;

        // Transfer fee tokens out to the receiver.
        store.transferOut(_feeToken, _receiver, _purchaseAmount);

        _logEvent("AcceptOffer", abi.encode(_feeToken, _receiver, _purchaseAmount, _burnAmount, _distributeAmount));
    }

    /**
     * @notice Sets the fixed redemption price for a fee token.
     * @dev This sets the total protocol token cost required to redeem ANY amount of unlocked fee tokens.
     * @param _feeToken The fee token.
     * @param _amount The fixed price in protocol tokens (not per-unit).
     */
    function setAskPrice(IERC20 _feeToken, uint _amount) external auth {
        askAmount[_feeToken] = _amount;
        _logEvent("SetAskAmount", abi.encode(_feeToken, _amount));
    }

    /**
     * @notice Internal function to update the unlocked balance for fee tokens.
     * @param _feeToken The fee token to update.
     */
    function _updateUnlockedBalance(
        IERC20 _feeToken
    ) internal {
        uint pendingUnlock = getPendingUnlock(_feeToken);
        if (pendingUnlock > 0) {
            accruedFee[_feeToken] += pendingUnlock;
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
        require(
            _config.burnBasisPoints == Precision.BASIS_POINT_DIVISOR || address(_config.feeDistributor) != address(0),
            "FeeMarketplace: reward distributor required when burn < 100%"
        );

        config = _config;
    }
}
