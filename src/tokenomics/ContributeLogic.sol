// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {CoreContract} from "../utils/CoreContract.sol";
import {EventEmitter} from "../utils/EventEmitter.sol";
import {Precision} from "../utils/Precision.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {IERC20Mintable} from "../utils/interfaces/IERC20Mintable.sol";
import {ContributeStore} from "./store/ContributeStore.sol";

/// @title ContributeLogic
/// @notice contract features a token-based incentive buy-back, it has self-contained mechanism operates without relying
/// on external price oracles or a single liquidity pool for each token contributed
/// distribution of rewards within the protocol, including locking mechanisms and bonus multipliers
/// for token holders.
//// @dev It calculates rewards for contributors based on a cumulative distribution rate, which increases with each
/// PUPPET token sold, enabling users to claim PUPPET rewards proportionate to their token contributions
contract ContributeLogic is CoreContract {
    /// @notice Struct to hold configuration parameters.
    struct Config {
        uint baselineEmissionRate;
    }

    /// @notice The configuration parameters for the ContributeLogic
    Config public config;

    /// @notice The contract used for minting rewards.
    IERC20Mintable public immutable rewardToken;

    /// @notice The RewardStore contract used for tracking reward accruals
    ContributeStore public immutable store;

    function getClaimable(address user) external view returns (uint) {
        return store.getUserAccruedReward(user);
    }

    constructor(
        IAuthority _authority,
        EventEmitter _eventEmitter,
        IERC20Mintable _rewardToken,
        ContributeStore _store,
        Config memory _config
    ) CoreContract("ContributeLogic", "1", _authority, _eventEmitter) {
        rewardToken = _rewardToken;
        store = _store;

        _setConfig(_config);
    }

    /// @notice Executes the buyback of revenue tokens using the protocol's accumulated fees.
    /// @param token The address of the revenue token to be bought back.
    /// @param depositor The address that deposits the buyback token.
    /// @param receiver The address that will receive the revenue token.
    /// @param revenueAmount The amount of the revenue token to be bought back.
    function buyback(IERC20 token, address depositor, address receiver, uint revenueAmount) external auth {
        uint quoteAmount = store.getBuybackQuote(token);

        if (quoteAmount == 0) revert ContributeLogic__InvalidBuybackToken();

        store.transferIn(rewardToken, depositor, quoteAmount);
        store.transferOut(token, receiver, revenueAmount);

        uint cursor = store.getCursor(token);
        store.setCursorReward(token, cursor, quoteAmount * Precision.FLOAT_PRECISION / revenueAmount);
        store.setCursor(token, cursor + 1);

        logEvent("buyback()", abi.encode(token, depositor, receiver, cursor, revenueAmount, quoteAmount));
    }

    /// @notice Update user cursor which to the current cursor.
    /// @param token The address of the token contribution.
    /// @param user The address of the contributor.
    function updateCursor(IERC20 token, address user) external auth {
        store.updateCursor(token, user);
    }

    /// @notice Claims the rewards for a specific token contribution.
    /// @param user The address of the contributor for whom the rewards are to be claimed.
    /// @param receiver The address that will receive the claimed rewards.
    /// @param amount The amount of rewards to be claimed.
    /// @return The amount of rewards claimed.
    function claim(address user, address receiver, uint amount) external auth returns (uint) {
        uint accruedReward = store.getUserAccruedReward(user);

        if (amount > accruedReward) revert ContributeLogic__InsufficientClaimableReward(accruedReward);

        uint nextAccruedReward = accruedReward - amount;
        uint reward = Precision.applyFactor(config.baselineEmissionRate, amount);

        store.setUserAccruedReward(user, nextAccruedReward);
        rewardToken.mint(receiver, reward);

        logEvent("claim()", abi.encode(user, nextAccruedReward, reward));

        return reward;
    }

    // governance

    /// @notice Set the buyback quote for the token.
    /// @param token The token for which the buyback quote is to be set.
    /// @param value The value of the buyback quote.
    function setBuybackQuote(IERC20 token, uint value) external auth {
        store.setBuybackQuote(token, value);
    }

    /// @notice Set the mint rate limit for the token.
    /// @param _config The new rate limit configuration.
    function setConfig(Config calldata _config) external auth {
        _setConfig(_config);
    }

    /// @dev Internal function to set the configuration.
    /// @param _config The configuration to set.
    function _setConfig(Config memory _config) internal {
        config = _config;
        logEvent("setConfig()", abi.encode(_config));
    }

    /// @notice Error emitted when the claim token is invalid
    error ContributeLogic__InvalidBuybackToken();

    /// @notice Error emitted when the claimable reward is insufficient
    error ContributeLogic__InsufficientClaimableReward(uint accruedReward);
}
