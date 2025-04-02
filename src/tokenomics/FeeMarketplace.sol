// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {Error} from "../shared/Error.sol";
import {TokenRouter} from "../shared/TokenRouter.sol";
import {BankStore} from "../utils/BankStore.sol";
import {CoreContract} from "../utils/CoreContract.sol";
import {Precision} from "../utils/Precision.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {FeeMarketplaceStore} from "./FeeMarketplaceStore.sol";
import {PuppetToken} from "./PuppetToken.sol";

/**
 * @title Protocol Fee Redemption Marketplace
 * @notice A marketplace where users exchange protocol tokens for accumulated fee tokens at fixed rates.
 *
 * @dev Key features of this redemption system:
 *      - Time-based linear unlocking of deposited fees
 *      - Fixed-rate exchange between protocol tokens and fee tokens
 *      - Configurable burning of received protocol tokens
 *      - Distribution of non-burned protocol tokens to a rewards contract
 *
 * @dev Operation process:
 *      1. Protocol fees are deposited and accumulate in the marketplace
 *      2. Fees unlock gradually over time based on the configured timeframe
 *      3. Users can redeem unlocked fees by providing protocol tokens at the set rate
 *      4. A portion of received protocol tokens are burned according to configuration
 *      5. Remaining protocol tokens are sent to the fee distributor contract
 */
contract FeeMarketplace is CoreContract {
    /**
     * @dev Marketplace configuration parameters
     * @param feeDistributor The BankStore contract that receives non-burned protocol tokens
     *        for distribution as rewards
     * @param distributionTimeframe Duration in seconds over which new fee deposits
     *        become fully unlocked (linear release)
     * @param burnBasisPoints Percentage of exchanged protocol tokens to burn, expressed in
     *        basis points (100 = 1%, 10000 = 100%)
     */
    struct Config {
        BankStore feeDistributor;
        uint distributionTimeframe;
        uint burnBasisPoints;
    }

    /// @notice Router contract for token transfers
    TokenRouter public immutable tokenRouter;

    /// @notice Store contract that holds the fee tokens
    FeeMarketplaceStore public immutable store;

    /// @notice The protocol's native governance token used for redemptions
    PuppetToken public immutable protocolToken;

    /// @notice Maps fee tokens to their redemption cost in protocol tokens
    mapping(IERC20 => uint) public askAmount;

    /// @notice Maps fee tokens to their unlocked (available) balance
    mapping(IERC20 => uint) public accruedFee;

    /// @notice Tracks the last time unlocked balances were calculated for each fee token
    mapping(IERC20 => uint) public lastDistributionTimestamp;

    /// @notice Current marketplace configuration parameters
    Config public config;

    constructor(
        IAuthority _authority,
        TokenRouter _tokenRouter,
        FeeMarketplaceStore _store,
        PuppetToken _protocolToken
    ) CoreContract(_authority) {
        tokenRouter = _tokenRouter;
        store = _store;
        protocolToken = _protocolToken;
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

        // Burn the designated portion of protocol tokens.

        if (config.burnBasisPoints > 0) {
            _burnAmount = Precision.applyBasisPoints(config.burnBasisPoints, _currentAskAmount);
            store.transferIn(protocolToken, _depositor, _currentAskAmount);
            store.burn(_burnAmount);
            _distributeAmount -= _burnAmount;
        }

        // Transfer the remaining tokens to the reward distributor.
        if (_distributeAmount > 0 && address(config.feeDistributor) != address(0)) {
            config.feeDistributor.interTransferIn(protocolToken, store, _distributeAmount);
        }

        // Deduct the redeemed fee tokens from the unlocked balance.
        accruedFee[_feeToken] = _accuredFees - _purchaseAmount;
        lastDistributionTimestamp[_feeToken] = block.timestamp;

        // Transfer fee tokens out to the receiver.
        store.transferOut(_feeToken, _receiver, _purchaseAmount);

        _logEvent("AcceptOffer", abi.encode(_feeToken, _receiver, _purchaseAmount, _burnAmount, _distributeAmount));
    }

    /**
     * @notice Sets the redemption cost (price in protocol tokens) for a fee token.
     * @param _feeToken The fee token.
     * @param _newCost The new cost in protocol tokens.
     */
    function setAskPrice(IERC20 _feeToken, uint _newCost) external auth {
        askAmount[_feeToken] = _newCost;
        _logEvent("SetRedemptionCost", abi.encode(_feeToken, _newCost));
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

    /**
     * @dev Updates the configuration of the fee marketplace.
     * @param _data The abi-encoded Config struct.
     */
    function _setConfig(
        bytes calldata _data
    ) internal override {
        Config memory newConfig = abi.decode(_data, (Config));
        require(
            newConfig.burnBasisPoints <= Precision.BASIS_POINT_DIVISOR, "FeeMarketplace: burn basis points exceeds 100%"
        );
        require(
            newConfig.burnBasisPoints == Precision.BASIS_POINT_DIVISOR
                || address(newConfig.feeDistributor) != address(0),
            "FeeMarketplace: reward distributor required when burn < 100%"
        );

        config = newConfig;

        _logEvent(
            "SetConfig",
            abi.encode(newConfig.distributionTimeframe, newConfig.burnBasisPoints, newConfig.feeDistributor)
        );
    }
}
