// SPDX-License-Identifier: GPL-3.0-or-later
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Voting Escrow Reward Distributor
 * @notice Distributes any tokens transferred to the contract (e.g. Protocol rewards and any token emissions) among veBPT
 * holders proportionally based on a snapshot of the week at which the tokens are sent to the RewardDistributor contract.
 * @dev Supports distributing arbitrarily many different tokens. In order to start distributing a new token to veBPT
 * holders simply transfer the tokens to the `RewardDistributor` contract and then call `checkpointToken`.
 */
interface IVeRevenueDistributor {
    event VeRevenueDistributor__TokenCheckpoint(IERC20 token, uint amount, uint lastCheckpointTimestamp);
    event VeRevenueDistributor__TokensClaim(address from, address to, IERC20 token, uint amount, uint userTokenTimeCursor);

    /**
     * @notice Returns the global time cursor representing the most earliest uncheckpointed week.
     */
    function getTimeCursor() external view returns (uint);

    /**
     * @notice Returns the user-level time cursor representing the most earliest uncheckpointed week.
     * @param user - The address of the user to query.
     */
    function getUserTimeCursor(address user) external view returns (uint);

    /**
     * @notice Returns the token-level time cursor storing the timestamp at up to which tokens have been distributed.
     * @param token - The ERC20 token address to query.
     */
    function getTokenTimeCursor(IERC20 token) external view returns (uint);

    /**
     * @notice Returns the user-level time cursor storing the timestamp of the latest token distribution claimed.
     * @param user - The address of the user to query.
     * @param token - The ERC20 token address to query.
     */
    function getUserTokenTimeCursor(address user, IERC20 token) external view returns (uint);

    /**
     * @notice Returns the user's cached balance of veBPT as of the provided timestamp.
     * @dev Only timestamps which fall on Thursdays 00:00:00 UTC will return correct values.
     * This function requires `user` to have been checkpointed past `timestamp` so that their balance is cached.
     * @param user - The address of the user of which to read the cached balance of.
     * @param timestamp - The timestamp at which to read the `user`'s cached balance at.
     */
    function getUserBalanceAtTimestamp(address user, uint timestamp) external view returns (uint);

    /**
     * @notice Returns the cached total supply of veBPT as of the provided timestamp.
     * @dev Only timestamps which fall on Thursdays 00:00:00 UTC will return correct values.
     * This function requires the contract to have been checkpointed past `timestamp` so that the supply is cached.
     * @param timestamp - The timestamp at which to read the cached total supply at.
     */
    function getTotalSupplyAtTimestamp(uint timestamp) external view returns (uint);

    /**
     * @notice Returns the RewardDistributor's cached balance of `token`.
     */
    function getTokenLastBalance(IERC20 token) external view returns (uint);

    /**
     * @notice Returns the amount of `token` which the RewardDistributor received in the week beginning at `timestamp`.
     * @param token - The ERC20 token address to query.
     * @param timestamp - The timestamp corresponding to the beginning of the week of interest.
     */
    function getTokensDistributedInWeek(IERC20 token, uint timestamp) external view returns (uint);

    // Depositing

    /**
     * @notice Deposits tokens to be distributed in the current week.
     * @dev Sending tokens directly to the RewardDistributor instead of using `depositTokens` may result in tokens being
     * retroactively distributed to past weeks, or for the distribution to carry over to future weeks.
     *
     * If for some reason `depositTokens` cannot be called, in order to ensure that all tokens are correctly distributed
     * manually call `checkpointToken` before and after the token transfer.
     * @param token - The ERC20 token address to distribute.
     * @param amount - The amount of tokens to deposit.
     */
    function depositToken(IERC20 token, uint amount) external;

    /**
     * @notice Deposits tokens to be distributed in the current week.
     * @dev A version of `depositToken` which supports depositing multiple `tokens` at once.
     * See `depositToken` for more details.
     * @param tokens - An array of ERC20 token addresses to distribute.
     * @param amounts - An array of token amounts to deposit.
     */
    function depositTokens(IERC20[] calldata tokens, uint[] calldata amounts) external;

    // Checkpointing

    /**
     * @notice Caches the total supply of veBPT at the beginning of each week.
     * This function will be called automatically before claiming tokens to ensure the contract is properly updated.
     */
    function checkpoint() external;

    /**
     * @notice Caches the user's balance of veBPT at the beginning of each week.
     * This function will be called automatically before claiming tokens to ensure the contract is properly updated.
     * @param user - The address of the user to be checkpointed.
     */
    function checkpointUser(address user) external;

    /**
     * @notice Assigns any newly-received tokens held by the RewardDistributor to weekly distributions.
     * @dev Any `token` balance held by the RewardDistributor above that which is returned by `getTokenLastBalance`
     * will be distributed evenly across the time period since `token` was last checkpointed.
     *
     * This function will be called automatically before claiming tokens to ensure the contract is properly updated.
     * @param token - The ERC20 token address to be checkpointed.
     */
    function checkpointToken(IERC20 token) external;

    /**
     * @notice Assigns any newly-received tokens held by the RewardDistributor to weekly distributions.
     * @dev A version of `checkpointToken` which supports checkpointing multiple tokens.
     * See `checkpointToken` for more details.
     * @param tokens - An array of ERC20 token addresses to be checkpointed.
     */
    function checkpointTokens(IERC20[] calldata tokens) external;

    // Claiming

    /**
     * @notice Claims all pending distributions of the provided token for a user.
     * @dev It's not necessary to explicitly checkpoint before calling this function, it will ensure the RewardDistributor
     * is up to date before calculating the amount of tokens to be claimed.
     * @param token - The ERC20 token address to claim.
     * @param from - The address from which to claim the tokens.
     * @param to - The address to which to send the claimed tokens.
     * @return The amount of `token` sent to `user` as a result of claiming.
     */
    function claim(IERC20 token, address from, address to) external returns (uint);

    /**
     * @notice Claims a number of tokens on behalf of a user.
     * @dev A version of `claimToken` which supports claiming multiple `tokens` on behalf of `user`.
     * See `claimToken` for more details.
     * @param tokenList - An array of ERC20 token addresses to claim.
     * @return An array of the amounts of each token in `tokens` sent to `user` as a result of claiming.
     */
    function claimMany(IERC20[] calldata tokenList, address from, address to) external returns (uint[] memory);

    error VeRevenueDistributor__InputLengthMismatch();
    error VeRevenueDistributor__VotingEscrowZeroTotalSupply();
    error VeRevenueDistributor__CannotStartBeforeCurrentWeek();
}
