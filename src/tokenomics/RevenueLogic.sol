// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {ReentrancyGuardTransient} from "../utils/ReentrancyGuardTransient.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {Permission} from "../utils/access/Permission.sol";
import {Precision} from "../utils/Precision.sol";
import {RevenueStore} from "src/tokenomics/store/RevenueStore.sol";

/// @title RevenueLogic
/// @notice Implements a buyback functionality where the protocol publicly offers to buy back its own tokens using accumulated whitelisted revenue
/// tokens with a specified threshold.
/// @dev The contract inherits from Permission to be used by permissioned contracts, EIP712, and ReentrancyGuardTransient to provide buyback
/// functionality with permission checks and reentrancy protection.
contract RevenueLogic is Permission, EIP712, ReentrancyGuardTransient {
    event RewardLogic__Buyback(address indexed buyer, uint thresholdAmount, IERC20 indexed token, uint rewardPerContributionCursor, uint totalFee);

    RevenueStore public immutable store;
    IERC20 public immutable buybackToken;

    /// @notice Initializes the contract with the specified authority, buyback token, and revenue store.
    /// @param _authority The address of the authority contract for permission checks.
    /// @param _buybackToken The address of the token to be bought back.
    /// @param _store The address of the revenue store contract.
    constructor(IAuthority _authority, IERC20 _buybackToken, RevenueStore _store) Permission(_authority) EIP712("Revenue Logic", "1") {
        store = _store;
        buybackToken = _buybackToken;
    }

    /// @notice Retrieves the revenue balance of a specific token in the revenue store.
    /// @param token The address of the token whose balance is to be retrieved.
    /// @return The balance of the specified token in the revenue store.
    function getRevenueBalance(IERC20 token) external view returns (uint) {
        return store.getTokenBalance(token);
    }

    /// @notice Executes the buyback of revenue tokens using the protocol's accumulated fees.
    /// @dev In effect permissioned contract would publicly allow this method to be called.
    /// @param depositor The address that deposits the buyback token.
    /// @param receiver The address that will receive the revenue token.
    /// @param revenueToken The address of the revenue token to be bought back.
    /// @param amount The amount of revenue tokens to be bought back.
    function buybackRevenue(address depositor, address receiver, IERC20 revenueToken, uint amount) external auth {
        uint thresholdAmount = store.getTokenBuybackOffer(revenueToken);

        if (thresholdAmount == 0) revert RewardLogic__InvalidClaimToken();

        store.transferIn(buybackToken, depositor, thresholdAmount);
        store.transferOut(revenueToken, receiver, amount);
        uint rewardPerContributionCursor = store.increaseTokenPerContributionCursor(revenueToken, Precision.toFactor(thresholdAmount, amount));

        emit RewardLogic__Buyback(depositor, thresholdAmount, revenueToken, rewardPerContributionCursor, amount);
    }

    error RewardLogic__InvalidClaimToken();
}
