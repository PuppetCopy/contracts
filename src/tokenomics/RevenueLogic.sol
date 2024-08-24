// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {BankStore} from "../shared/store/BankStore.sol";
import {CoreContract} from "../utils/CoreContract.sol";
import {EventEmitter} from "../utils/EventEmitter.sol";
import {Precision} from "../utils/Precision.sol";
import {Permission} from "../utils/access/Permission.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {RevenueStore} from "./store/RevenueStore.sol";

/// @title RevenueLogic
/// @notice contract features a token-based incentive buy-back, it has self-contained mechanism operates without relying
/// on external price oracles or a single liquidity pool for each token like ETH, USDC etc
/// @dev It calculates rewards for contributors based on a cumulative distribution rate, which increases with each
/// PUPPET token sale, enabling users to claim PUPPET rewards proportionate to their token contributions
/// functionality with permission checks and reentrancy protection.
contract RevenueLogic is CoreContract {
    RevenueStore public immutable store;
    IERC20 public immutable buybackToken;

    function getClaimable(IERC20 token, address contributor) external view returns (uint) {
        uint cumTokenPerContrib = store.getCumulativeRewardPerContribution(token);
        uint userRewardPerContrib = store.getUserRewardPerContribution(token, contributor);

        uint accruedReward = store.getUserAccruedReward(token, contributor);

        if (cumTokenPerContrib > userRewardPerContrib) {
            uint cumContribution = store.getUserCumulativeContribution(token, contributor);
            accruedReward += cumContribution * (cumTokenPerContrib - userRewardPerContrib) / Precision.FLOAT_PRECISION;
        }

        return accruedReward;
    }

    /// @notice Initializes the contract with the specified authority, buyback token, and revenue store.
    /// @param _authority The address of the authority contract for permission checks.
    /// @param _buybackToken The address of the token to be bought back.
    /// @param _store The address of the revenue store contract.
    constructor(
        IAuthority _authority,
        EventEmitter _eventEmitter,
        IERC20 _buybackToken,
        RevenueStore _store
    )
        // Config memory _config
        CoreContract("RevenueLogic", "1", _authority, _eventEmitter)
    {
        buybackToken = _buybackToken;
        store = _store;
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
    /// @param token The address of the revenue token to be bought back.
    /// @param amount The amount of revenue tokens to be bought back.
    function buyback(address depositor, address receiver, IERC20 token, uint amount) external auth {
        uint thresholdAmount = store.getTokenBuybackOffer(token);

        if (thresholdAmount == 0) revert RevenueLogic__InvalidClaimToken();

        store.transferIn(buybackToken, depositor, thresholdAmount);
        store.transferOut(token, receiver, amount);
        uint nextCumulativeTokenPerContrib =
            store.increaseCumulativeRewardPerContribution(token, Precision.toFactor(thresholdAmount, amount));

        eventEmitter.log(
            "RevenueLogic__Buyback",
            abi.encode(token, depositor, receiver, nextCumulativeTokenPerContrib, thresholdAmount, amount)
        );
    }

    // function distribute(IERC20 token, uint amount) external auth {
    //     store.distribute(token, amount);
    // }

    function claim(IERC20 token, address contributor, address receiver, uint amount) external {
        uint accruedReward = updateUserCursor(token, contributor);

        if (amount > accruedReward) revert RevenueLogic__InsufficientClaimableReward();

        uint nextAccruedReward = accruedReward - amount;

        store.setUserAccruedReward(token, contributor, nextAccruedReward);

        eventEmitter.log("RevenueLogic__Claim", abi.encode(token, contributor, receiver, nextAccruedReward, amount));
    }

    // internal
    function updateUserCursor(IERC20 token, address contributor) internal returns (uint) {
        uint cumTokenPerContrib = store.getCumulativeRewardPerContribution(token);
        uint userRewardPerContrib = store.getUserRewardPerContribution(token, contributor);

        uint accruedReward = store.getUserAccruedReward(token, contributor);

        if (cumTokenPerContrib > userRewardPerContrib) {
            uint cumContribution = store.getUserCumulativeContribution(token, contributor);
            accruedReward = store.getUserAccruedReward(token, contributor)
                + cumContribution * (cumTokenPerContrib - userRewardPerContrib) / Precision.FLOAT_PRECISION;
            store.setUserAccruedReward(token, contributor, accruedReward);
        }

        return accruedReward;
    }

    error RevenueLogic__InvalidClaimToken();
    error RevenueLogic__InsufficientClaimableReward();
}
