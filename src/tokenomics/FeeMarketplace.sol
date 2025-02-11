// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {Error} from "../shared/Error.sol";
import {TokenRouter} from "../shared/TokenRouter.sol";
import {BankStore} from "../shared/store/BankStore.sol";
import {CoreContract} from "../utils/CoreContract.sol";
import {Precision} from "../utils/Precision.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {PuppetToken} from "./PuppetToken.sol";
import {FeeMarketplaceStore} from "./store/FeeMarketplaceStore.sol";

/**
 * @title Protocol Public Fee Marketplace
 * @notice Exchange protocol tokens for protocol-collected fees at governance-set rates.
 * @dev Implements a fixed-rate redemption system with:
 *  - Gradual fee availability (linear unlock over a configured timeframe)
 *  - Fixed protocol token cost per fee type, set by governance
 *  - Permanent burn of a portion of protocol tokens on redemption
 *  - Remaining protocol tokens sent to rewards pool
 *
 * Flow:
 * 1. Fees accumulate in the system through protocol operations.
 * 2. Deposited fees gradually unlock over time based on a distributionTimeframe.
 * 3. Users exchange protocol tokens for available fees at fixed rates.
 * 4. Exchanged protocol tokens are burned with the remaining sent to rewards.
 */
contract FeeMarketplace is CoreContract {
    /**
     * @dev Controls market parameters.
     * @param distributionTimeframe Time window for new fee deposits to fully unlock.
     * @param burnBasisPoints Percentage of protocol tokens to burn on exchange (10000 = 100%).
     * @param rewardDistributor Address receiving the remaining protocol tokens.
     */
    struct Config {
        uint distributionTimeframe;
        uint burnBasisPoints;
        address rewardDistributor;
    }

    TokenRouter public immutable tokenRouter;
    BankStore public immutable store;
    PuppetToken public immutable protocolToken;

    // Mapping for each fee token to its redemption cost in protocol tokens.
    mapping(IERC20 => uint) public askPrice;
    // Mapping for each fee token to the accrued (i.e., unlocked) fee balance.
    mapping(IERC20 => uint) public accruedFee;
    // Mapping to track the last timestamp when the fee unlock calculation occurred.
    mapping(IERC20 => uint) public lastDistributionTimestamp;

    Config public config;

    constructor(
        IAuthority _authority,
        TokenRouter _tokenRouter,
        FeeMarketplaceStore _store,
        PuppetToken _protocolToken
    ) CoreContract("BuyAndBurn", "1", _authority) {
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
     * @notice Deposits fees into the system and updates the unlocked fee balance.
     * @param feeToken The fee token being deposited.
     * @param depositor The address making the deposit.
     * @param amount The deposit amount.
     */
    function deposit(IERC20 feeToken, address depositor, uint amount) external auth {
        if (amount == 0) revert Error.FeeMarketplace__ZeroDeposit();

        // Update the fee token's unlocked balance before processing the deposit.
        _updateUnlockedBalance(feeToken);

        // Transfer fee tokens into the BankStore.
        store.transferIn(feeToken, depositor, amount);

        _logEvent("Deposit", abi.encode(feeToken, depositor, amount));
    }

    /**
     * @notice Executes a fee redemption offer.
     * @param feeToken The fee token to be redeemed.
     * @param receiver The address receiving fee tokens.
     * @param purchaseAmount The amount of fee tokens to redeem.
     */
    function acceptOffer(
        IERC20 feeToken,
        address user,
        address receiver,
        uint purchaseAmount
    ) external auth {
        uint currentAskPrice = askPrice[feeToken];
        if (currentAskPrice == 0) {
            revert Error.FeeMarketplace__NotAuctionableToken();
        }

        // Update the fee token's unlocked balance before redemption.
        _updateUnlockedBalance(feeToken);

        uint available = accruedFee[feeToken];
        if (available < purchaseAmount) revert Error.FeeMarketplace__InsufficientUnlockedBalance(available);

        // Calculate protocol token burn and reward amounts.
        uint burnAmount = Precision.applyBasisPoints(config.burnBasisPoints, currentAskPrice);
        uint rewardAmount = currentAskPrice - burnAmount;

        // Transfer protocol tokens from the user to the contract.
        tokenRouter.transfer(protocolToken, user, address(this), currentAskPrice);

        // Burn the designated portion of protocol tokens.
        protocolToken.burn(burnAmount);

        // Transfer the remaining tokens to the reward distributor.
        if (rewardAmount > 0) {
            protocolToken.transfer(config.rewardDistributor, rewardAmount);
        }

        // Deduct the redeemed fee tokens from the unlocked balance.
        accruedFee[feeToken] = available - purchaseAmount;
        lastDistributionTimestamp[feeToken] = block.timestamp;

        // Transfer fee tokens out to the receiver.
        store.transferOut(feeToken, receiver, purchaseAmount);

        _logEvent("AcceptOffer", abi.encode(feeToken, receiver, purchaseAmount, burnAmount, rewardAmount));
    }

    /**
     * @notice Sets the redemption cost (price in protocol tokens) for a fee token.
     * @param feeToken The fee token.
     * @param newCost The new cost in protocol tokens.
     */
    function setAskPrice(IERC20 feeToken, uint newCost) external auth {
        askPrice[feeToken] = newCost;
        _logEvent("SetRedemptionCost", abi.encode(feeToken, newCost));
    }

    /**
     * @notice Internal function to update the unlocked balance for fee tokens.
     * @param feeToken The fee token to update.
     */
    function _updateUnlockedBalance(
        IERC20 feeToken
    ) internal {
        uint pendingUnlock = getPendingUnlock(feeToken);
        if (pendingUnlock > 0) {
            accruedFee[feeToken] += pendingUnlock;
        }
        lastDistributionTimestamp[feeToken] = block.timestamp;
    }

    /**
     * @dev Updates the configuration of the fee marketplace.
     * @param data The abi-encoded Config struct.
     */
    function _setConfig(
        bytes calldata data
    ) internal override {
        Config memory newConfig = abi.decode(data, (Config));
        require(newConfig.burnBasisPoints <= 10000, "FeeMarketplace: burn basis points exceeds 100%");
        require(
            newConfig.burnBasisPoints == 10000 || newConfig.rewardDistributor != address(0),
            "FeeMarketplace: reward distributor required when burn < 100%"
        );

        config = newConfig;

        _logEvent(
            "SetConfig",
            abi.encode(newConfig.distributionTimeframe, newConfig.burnBasisPoints, newConfig.rewardDistributor)
        );
    }
}
