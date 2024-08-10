// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {ReentrancyGuardTransient} from "../utils/ReentrancyGuardTransient.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {Permission} from "../utils/access/Permission.sol";
import {Precision} from "../utils/Precision.sol";
import {RevenueStore} from "src/token/store/RevenueStore.sol";

/**
 * @title RevenueLogic
 * @dev buyback functionality where the protocol publicly offers to buy back Protocol tokens using accumulated ETH fees once a predefined threshold is
 * reached. This incentivizes participants to sell tokens for whitelisted revenue tokens without relying on price oracles per revenue token.
 */
contract RevenueLogic is Permission, EIP712, ReentrancyGuardTransient {
    event RewardLogic__Buyback(address buyer, uint thresholdAmount, IERC20 token, uint rewardPerContributionCursor, uint totalFee);

    RevenueStore immutable store;
    IERC20 immutable buybackToken;

    constructor(IAuthority _authority, IERC20 _buybackToken, RevenueStore _store) Permission(_authority) EIP712("Revenue Logic", "1") {
        store = _store;
        buybackToken = _buybackToken;
    }

    // external

    function getRevenueBalance(IERC20 token) external view returns (uint) {
        return store.getTokenBalance(token);
    }

    function buybackRevenue(address source, address depositor, address reciever, IERC20 revenueToken, uint amount) external auth {
        uint thresholdAmount = store.getTokenBuybackOffer(revenueToken);

        if (thresholdAmount == 0) revert RewardLogic__InvalidClaimToken();

        store.transferIn(buybackToken, depositor, thresholdAmount);
        store.transferOut(revenueToken, reciever, amount);
        uint rewardPerContributionCursor = store.increaseTokenPerContributionCursor(revenueToken, Precision.toFactor(thresholdAmount, amount));

        emit RewardLogic__Buyback(depositor, thresholdAmount, revenueToken, rewardPerContributionCursor, amount);
    }

    error RewardLogic__InvalidClaimToken();
}
