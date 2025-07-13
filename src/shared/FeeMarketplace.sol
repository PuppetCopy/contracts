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
 * @title Fee Marketplace
 * @notice Publicly offers accumulated protocol fees to trade with protocol tokens at a fixed price
 *
 * @dev Core mechanics:
 * - Fee tokens unlock gradually over time after deposit
 * - Each fee token has a fixed redemption price (askAmount)
 * - Fixed price applies regardless of purchase amount (up to available balance)
 * - Public can purchase any amount of unlocked tokens at the posted price
 * - Protocol tokens received are burned/distributed per configuration
 *
 * @dev Example: If askAmount[USDC] = 1000:
 * - Taker paying 1000 protocol tokens can redeem any amount up to unlocked balance
 * - Price remains 1000 whether purchasing 100 USDC or 2000 USDC
 * - Protocol offers flexible quantity purchases at this fixed price
 */
contract FeeMarketplace is CoreContract {
    /**
     * @param distributionTimeframe Unlock duration for deposits (seconds)
     * @param burnBasisPoints Protocol tokens to burn (basis points: 100 = 1%)
     */
    struct Config {
        uint transferOutGasLimit;
        uint distributionTimeframe;
        uint burnBasisPoints;
    }

    /// @notice Protocol token used for purchases
    PuppetToken public immutable protocolToken;

    /// @notice Holds fee tokens
    FeeMarketplaceStore public immutable store;

    /// @notice Fixed price to redeem any amount of each fee token
    mapping(IERC20 => uint) public askAmount;

    /// @notice Currently unlocked balance per fee token
    mapping(IERC20 => uint) public unclockedFees;

    /// @notice Last unlock calculation timestamp per fee token
    mapping(IERC20 => uint) public lastDistributionTimestamp;

    /// @notice Available protocol tokens for distribution (after burns)
    uint public distributionBalance;

    /// @notice Current marketplace settings
    Config public config;

    constructor(
        IAuthority _authority,
        PuppetToken _protocolToken,
        FeeMarketplaceStore _store,
        Config memory _config
    ) CoreContract(_authority) {
        protocolToken = _protocolToken;
        store = _store;

        _setConfig(abi.encode(_config));
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
        uint unlockedAmount = unclockedFees[feeToken];

        if (totalDeposited <= unlockedAmount) return 0;

        uint newDepositAmount = totalDeposited - unlockedAmount;
        uint timeElapsed = block.timestamp - lastDistributionTimestamp[feeToken];

        pending = Math.min((newDepositAmount * timeElapsed) / config.distributionTimeframe, newDepositAmount);
    }

    /**
     * @notice Returns the total fee balance that is available for redemption.
     * @param feeToken The fee token.
     * @return Total unlocked fee balance.
     */
    function getTotalUnlocked(
        IERC20 feeToken
    ) public view returns (uint) {
        return unclockedFees[feeToken] + getPendingUnlock(feeToken);
    }

    /**
     * @notice Deposits fee tokens into the marketplace.
     * @param _feeToken The fee token to deposit.
     * @param _depositor The address depositing the tokens.
     * @param _amount The amount of tokens to deposit.
     */
    function deposit(IERC20 _feeToken, address _depositor, uint _amount) external auth {
        require(_amount > 0, Error.FeeMarketplace__ZeroDeposit());

        _updateUnlockedBalance(_feeToken);

        store.transferIn(_feeToken, _depositor, _amount);

        _logEvent("Deposit", abi.encode(_feeToken, _amount));
    }

    /**
     * @notice Records unaccounted transferred tokens to the store and syncs internal accounting.
     * @param _feeToken The fee token to record.
     * @return _amount The actual amount transferred.
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
     * @notice Sets the fixed redemption price for a fee token.
     * @dev This sets the protocol token cost required to redeem any amount of unlocked fee tokens.
     * @param _feeToken The fee token.
     * @param _amount The fixed price in protocol tokens.
     */
    function setAskPrice(IERC20 _feeToken, uint _amount) external auth {
        askAmount[_feeToken] = _amount;
        _logEvent("SetAskAmount", abi.encode(_feeToken, _amount));
    }

    /**
     * @notice Transfers protocol tokens to receiver
     * @param _receiver Address to receive the tokens
     * @param _amount Amount of protocol tokens to transfer
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

    /**
     * @notice Internal function to update the unlocked balance for fee tokens.
     * @param _feeToken The fee token to update.
     */
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
