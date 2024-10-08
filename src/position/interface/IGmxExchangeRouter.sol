// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import {GmxPositionUtils} from "./../utils/GmxPositionUtils.sol";

interface IGmxExchangeRouter {
    /// @dev Executes multiple calls in a single transaction, and returns the results of each call.
    function multicall(bytes[] calldata data) external payable returns (bytes[] memory results);

    function sendWnt(address receiver, uint amount) external payable;
    function sendNativeToken(address receiver, uint amount) external payable;
    /// @dev Sends the given amount of tokens to the given address
    function sendTokens(address token, address receiver, uint amount) external payable;

    /// @dev Creates a new order with the given amount, order parameters. The order is
    ///      created by transferring the specified amount of collateral tokens from the caller's account to the
    ///      order store, and then calling the `createOrder()` function on the order handler contract. The
    ///      referral code is also set on the caller's account using the referral storage contract.
    function createOrder(GmxPositionUtils.CreateOrderParams calldata params) external payable returns (bytes32);


    /**
     * @dev Cancels the given order. The `cancelOrder()` feature must be enabled for the given order
     * type. The caller must be the owner of the order, and the order must not be a market order. The
     * order is cancelled by calling the `cancelOrder()` function in the `OrderUtils` contract. This
     * function also records the starting gas amount and the reason for cancellation, which is passed to
     * the `cancelOrder()` function.
     *
     * @param key The unique ID of the order to be cancelled
     */
    function cancelOrder(bytes32 key) external payable;

    /**
     * @dev Claims funding fees for the given markets and tokens on behalf of the caller, and sends the
     * fees to the specified receiver. The length of the `markets` and `tokens` arrays must be the same.
     * For each market-token pair, the `claimFundingFees()` function in the `MarketUtils` contract is
     * called to claim the fees for the caller.
     *
     * @param markets An array of market addresses
     * @param tokens An array of token addresses, corresponding to the given markets
     * @param receiver The address to which the claimed fees should be sent
     */
    function claimFundingFees(address[] memory markets, address[] memory tokens, address receiver) external payable returns (uint[] memory);

    /**
     * @dev Claims affiliate rewards for the given markets and tokens on behalf of the caller, and sends
     * the rewards to the specified receiver. The length of the `markets` and `tokens` arrays must be
     * the same. For each market-token pair, the `claimAffiliateReward()` function in the `ReferralUtils`
     * contract is called to claim the rewards for the caller.
     *
     * @param markets An array of market addresses
     * @param tokens An array of token addresses, corresponding to the given markets
     * @param receiver The address to which the claimed rewards should be sent
     */
    function claimAffiliateRewards(address[] memory markets, address[] memory tokens, address receiver) external payable returns (uint[] memory);
}
