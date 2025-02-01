// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";

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
 * @notice Exchange protocol tokens for protocol-collected fees at governance-set rates
 * @dev Implements a fixed-rate redemption system with:
 * - Gradual fee availability (linear unlock over configured timeframe)
 * - Fixed protocol token cost per fee type, set by governance
 * - Permanent burn of portion of protocol tokens on redemption
 * - Remaining protocol tokens sent to rewards pool
 *
 * Flow:
 * 1. Fees accumulate in the system through protocol operations
 * 2. Deposited fees become claimable over time (drip mechanism)
 * 3. Users exchange protocol tokens for available fees at fixed rates
 * 4. Exchanged protocol tokens are burned, rest sent to rewards
 */
contract FeeMarketplace is CoreContract, ReentrancyGuardTransient {
    /**
     * @dev Controls market parameters
     * @param distributionTimeframe Time window for new fee deposits to fully unlock
     * @param burnBasisPoints Percentage of protocol tokens destroyed on exchange (10000 = 100%)
     * @param rewardDistributor Address receiving unburned protocol tokens
     */
    struct Config {
        uint distributionTimeframe;
        uint burnBasisPoints;
        address rewardDistributor;
    }

    TokenRouter public immutable tokenRouter;
    BankStore public immutable store;
    PuppetToken public immutable protocolToken;

    mapping(IERC20 => uint) public askAmount;
    mapping(IERC20 => uint) public accruedFeeBalance;
    mapping(IERC20 => uint) public lastUpdateTimestamp;

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

    function getPendingUnlock(
        IERC20 feeToken
    ) public view returns (uint pending) {
        uint totalDeposited = store.getTokenBalance(feeToken);
        uint alreadyUnlocked = accruedFeeBalance[feeToken];

        if (totalDeposited <= alreadyUnlocked) return 0;

        uint netNewDeposits = totalDeposited - alreadyUnlocked;
        uint timeElapsed = block.timestamp - lastUpdateTimestamp[feeToken];

        pending = Math.min((netNewDeposits * timeElapsed) / config.distributionTimeframe, netNewDeposits);
    }

    function getTotalUnlocked(
        IERC20 feeToken
    ) public view returns (uint) {
        return accruedFeeBalance[feeToken] + getPendingUnlock(feeToken);
    }

    function deposit(IERC20 feeToken, address depositor, uint amount) external auth {
        if (amount == 0) revert Error.FeeMarketplace__ZeroDeposit();

        accruedFeeBalance[feeToken] += getPendingUnlock(feeToken);
        lastUpdateTimestamp[feeToken] = block.timestamp;

        store.transferIn(feeToken, depositor, amount);
        _logEvent("Deposit", abi.encode(feeToken, depositor, amount));
    }

    function acceptOffer(IERC20 feeToken, address receiver, uint purchaseAmount) external nonReentrant {
        uint currentAsk = askAmount[feeToken];
        if (currentAsk == 0) revert Error.FeeMarketplace__NotAuctionableToken();

        uint available = getTotalUnlocked(feeToken);

        if (available < purchaseAmount) {
            revert Error.FeeMarketplace__InsufficientUnlockedBalance(available);
        }


        uint burnAmount = Precision.applyBasisPoints(config.burnBasisPoints, currentAsk);
        uint rewardAmount = currentAsk - burnAmount;

        tokenRouter.transfer(protocolToken, msg.sender, address(this), currentAsk);
        protocolToken.burn(burnAmount);

        if (rewardAmount > 0) {
            // Safe due to config validation in _setConfig
            protocolToken.transfer(config.rewardDistributor, rewardAmount);
        }
        accruedFeeBalance[feeToken] = available - purchaseAmount;
        lastUpdateTimestamp[feeToken] = block.timestamp;

        store.transferOut(feeToken, receiver, purchaseAmount);

        _logEvent("AcceptOffer", abi.encode(feeToken, receiver, purchaseAmount, burnAmount, rewardAmount));
    }

    function setAskAmount(IERC20 feeToken, uint newCost) external auth {
        askAmount[feeToken] = newCost;
        _logEvent("SetAskCost", abi.encode(feeToken, newCost));
    }

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
    }
}
