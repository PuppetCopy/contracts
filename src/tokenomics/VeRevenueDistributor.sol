// SPDX-License-Identifier: GPL-3.0
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

pragma solidity 0.8.24;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";

import {VotingEscrow} from "./VotingEscrow.sol";
import {Router} from "../utils/Router.sol";
import {IVeRevenueDistributor} from "../utils/interfaces/IVeRevenueDistributor.sol";

/**
 * @title Fee Distributor
 * @notice Distributes any tokens transferred to the contract (e.g. Protocol fees and any token emissions) among vetoken
 * holders proportionally based on a snapshot of the week at which the tokens are sent to the FeeDistributor contract.
 * @dev Supports distributing arbitrarily many different tokens. In order to start distributing a new token to vetoken
 * holders simply transfer the tokens to the `FeeDistributor` contract and then call `checkpointToken`.
 * slightly modified from https://github.com/ZeframLou/fee-distributor/blob/main/src/FeeDistributor.sol
 */
contract VeRevenueDistributor is Auth, EIP712, IVeRevenueDistributor, ReentrancyGuard {
    uint private immutable _startTime;
    VotingEscrow public immutable _votingEscrow;
    Router public immutable router;

    // Global State
    uint private _timeCursor;
    mapping(uint => uint) private _veSupplyCache;

    // Token State

    // `startTime` and `timeCursor` are both timestamps so comfortably fit in a uint64.
    // `cachedBalance` will comfortably fit the total supply of any meaningful token.
    // Should more than 2^128 tokens be sent to this contract then checkpointing this token will fail until enough
    // tokens have been claimed to bring the total balance back below 2^128.
    struct TokenState {
        uint64 startTime;
        uint64 timeCursor;
        uint128 cachedBalance;
    }

    mapping(IERC20 => TokenState) private _tokenState;
    mapping(IERC20 => mapping(uint => uint)) private _tokensPerWeek;

    // User State

    // `startTime` and `timeCursor` are timestamps so will comfortably fit in a uint64.
    // For `lastEpochCheckpointed` to overflow would need over 2^128 transactions to the VotingEscrow contract.
    struct UserState {
        uint64 startTime;
        uint64 timeCursor;
        uint128 lastEpochCheckpointed;
    }

    mapping(address => UserState) internal _userState;
    mapping(address => mapping(uint => uint)) private _userBalanceAtTimestamp;
    mapping(address => mapping(IERC20 => uint)) private _userTokenTimeCursor;

    constructor(Authority _authority, VotingEscrow votingEscrow, Router _router, uint startTime)
        Auth(address(0), _authority)
        EIP712("VeRevenueDistributor", "1")
    {
        _votingEscrow = votingEscrow;
        router = _router;

        startTime = _roundEpochTime(startTime);
        uint currentWeek = _roundEpochTime(block.timestamp);

        if (startTime < currentWeek) {
            revert VeRevenueDistributor__CannotStartBeforeCurrentWeek();
        }
        if (startTime == currentWeek) {
            // We assume that `votingEscrow` has been deployed in a week previous to this one.
            // If `votingEscrow` did not have a non-zero supply at the beginning of the current week
            // then any tokens which are distributed this week will be lost permanently.
            if (votingEscrow.totalSupply(currentWeek) == 0) {
                revert VeRevenueDistributor__VotingEscrowZeroTotalSupply();
            }
        }
        _startTime = startTime;
        _timeCursor = startTime;
    }

    // View

    function getTimeCursor() external view returns (uint) {
        return _timeCursor;
    }

    function getUserTimeCursor(address user) external view returns (uint) {
        return _userState[user].timeCursor;
    }

    function getTokenTimeCursor(IERC20 token) external view returns (uint) {
        return _tokenState[token].timeCursor;
    }

    function getUserTokenTimeCursor(address user, IERC20 token) external view returns (uint) {
        return _getUserTokenTimeCursor(user, token);
    }

    function getUserBalanceAtTimestamp(address user, uint timestamp) external view returns (uint) {
        return _userBalanceAtTimestamp[user][timestamp];
    }

    function getTotalSupplyAtTimestamp(uint timestamp) external view returns (uint) {
        return _veSupplyCache[timestamp];
    }

    function getTokenLastBalance(IERC20 token) external view returns (uint) {
        return _tokenState[token].cachedBalance;
    }

    function getTokensDistributedInWeek(IERC20 token, uint timestamp) external view returns (uint) {
        return _tokensPerWeek[token][timestamp];
    }

    function getClaimableToken(IERC20 token, address user) public view returns (uint) {
        TokenState memory tokenState = _tokenState[token];
        (uint amount,) = _getClaimableToken(token, tokenState, user);
        return amount;
    }

    /// -----------------------------------------------------------------------
    /// User actions
    /// -----------------------------------------------------------------------

    // Depositing

    function depositToken(IERC20 token, uint amount) external {
        _checkpointToken(token, false);
        SafeERC20.safeTransferFrom(token, msg.sender, address(this), amount);
        _checkpointToken(token, true);
    }

    function depositTokens(IERC20[] calldata tokens, uint[] calldata amounts) external {
        if (tokens.length != amounts.length) {
            revert VeRevenueDistributor__InputLengthMismatch();
        }

        uint length = tokens.length;
        for (uint i = 0; i < length;) {
            _checkpointToken(tokens[i], false);
            SafeERC20.safeTransferFrom(tokens[i], msg.sender, address(this), amounts[i]);
            _checkpointToken(tokens[i], true);

            unchecked {
                ++i;
            }
        }
    }

    // Checkpointing

    /**
     * @notice Caches the total supply of vetoken at the beginning of each week.
     * This function will be called automatically before claiming tokens to ensure the contract is properly updated.
     */
    function checkpoint() external override nonReentrant {
        _checkpointTotalSupply();
    }

    /**
     * @notice Caches the user's balance of vetoken at the beginning of each week.
     * This function will be called automatically before claiming tokens to ensure the contract is properly updated.
     * @param user - The address of the user to be checkpointed.
     */
    function checkpointUser(address user) external override nonReentrant {
        _checkpointUserBalance(user);
    }

    /**
     * @notice Assigns any newly-received tokens held by the FeeDistributor to weekly distributions.
     * @dev Any `token` balance held by the FeeDistributor above that which is returned by `getTokenLastBalance`
     * will be distributed evenly across the time period since `token` was last checkpointed.
     *
     * This function will be called automatically before claiming tokens to ensure the contract is properly updated.
     * @param token - The ERC20 token address to be checkpointed.
     */
    function checkpointToken(IERC20 token) external override nonReentrant {
        _checkpointToken(token, true);
    }

    /**
     * @notice Assigns any newly-received tokens held by the FeeDistributor to weekly distributions.
     * @dev A version of `checkpointToken` which supports checkpointing multiple tokens.
     * See `checkpointToken` for more details.
     * @param tokens - An array of ERC20 token addresses to be checkpointed.
     */
    function checkpointTokens(IERC20[] calldata tokens) external override nonReentrant {
        uint tokensLength = tokens.length;
        for (uint i = 0; i < tokensLength;) {
            _checkpointToken(tokens[i], true);

            unchecked {
                ++i;
            }
        }
    }

    function claim(IERC20 token, address from, address to) external requiresAuth returns (uint) {
        _checkpointTotalSupply();
        _checkpointUserBalance(from);
        _checkpointToken(token, false);

        uint amount = _claimToken(token, from, to);
        return amount;
    }

    function claimList(IERC20[] calldata tokenList, address from, address to) external requiresAuth returns (uint[] memory) {
        _checkpointTotalSupply();
        _checkpointUserBalance(from);

        uint tokensLength = tokenList.length;
        uint[] memory amounts = new uint[](tokensLength);
        for (uint i = 0; i < tokensLength;) {
            _checkpointToken(tokenList[i], false);
            amounts[i] = _claimToken(tokenList[i], from, to);

            unchecked {
                ++i;
            }
        }

        return amounts;
    }

    function _claimToken(IERC20 token, address from, address to) internal returns (uint) {
        TokenState storage tokenState = _tokenState[token];
        uint nextUserTokenWeekToClaim = _getUserTokenTimeCursor(from, token);

        // The first week which cannot be correctly claimed is the earliest of:
        // - A) The global or user time cursor (whichever is earliest), rounded up to the end of the week.
        // - B) The token time cursor, rounded down to the beginning of the week.
        //
        // This prevents the two failure modes:
        // - A) A user may claim a week for which we have not processed their balance, resulting in tokens being locked.
        // - B) A user may claim a week which then receives more tokens to be distributed. However the user has
        //      already claimed for that week so their share of these new tokens are lost.
        uint firstUnclaimableWeek =
            Math.min(_roundUpTimestamp(Math.min(_timeCursor, _userState[from].timeCursor)), _roundEpochTime(tokenState.timeCursor));

        mapping(uint => uint) storage tokensPerWeek = _tokensPerWeek[token];
        mapping(uint => uint) storage userBalanceAtTimestamp = _userBalanceAtTimestamp[from];

        uint amount;
        for (uint i = 0; i < 20; ++i) {
            // We clearly cannot claim for `firstUnclaimableWeek` and so we break here.
            if (nextUserTokenWeekToClaim >= firstUnclaimableWeek) break;

            amount += (tokensPerWeek[nextUserTokenWeekToClaim] * userBalanceAtTimestamp[nextUserTokenWeekToClaim])
                / _veSupplyCache[nextUserTokenWeekToClaim];
            nextUserTokenWeekToClaim += 1 weeks;
        }
        // Update the stored user-token time cursor to prevent this user claiming this week again.
        _userTokenTimeCursor[from][token] = nextUserTokenWeekToClaim;

        if (amount > 0) {
            // For a token to be claimable it must have been added to the cached balance so this is safe.
            tokenState.cachedBalance = uint128(tokenState.cachedBalance - amount);
            SafeERC20.safeTransfer(token, to, amount);
            emit VeRevenueDistributor__TokensClaim(from, to, token, amount, nextUserTokenWeekToClaim);
        }

        return amount;
    }

    /**
     * @dev Calculate the amount of `token` to be distributed to `_votingEscrow` holders since the last checkpoint.
     */
    function _checkpointToken(IERC20 token, bool force) internal {
        TokenState storage tokenState = _tokenState[token];
        uint lastTokenTime = tokenState.timeCursor;
        uint timeSinceLastCheckpoint;
        if (lastTokenTime == 0) {
            // If it's the first time we're checkpointing this token then start distributing from now.
            // Also mark at which timestamp users should start attempts to claim this token from.
            lastTokenTime = block.timestamp;
            tokenState.startTime = uint64(_roundEpochTime(block.timestamp));

            // Prevent someone from assigning tokens to an inaccessible week.
            require(block.timestamp > _startTime, "Reward distribution has not started yet");
        } else {
            timeSinceLastCheckpoint = block.timestamp - lastTokenTime;

            if (!force) {
                // Checkpointing N times within a single week is completely equivalent to checkpointing once at the end.
                // We then want to get as close as possible to a single checkpoint every Wed 23:59 UTC to save gas.

                // We then skip checkpointing if we're in the same week as the previous checkpoint.
                bool alreadyCheckpointedThisWeek = _roundEpochTime(block.timestamp) == _roundEpochTime(lastTokenTime);
                // However we want to ensure that all of this week's rewards are assigned to the current week without
                // overspilling into the next week. To mitigate this, we checkpoint if we're near the end of the week.
                bool nearingEndOfWeek = _roundUpTimestamp(block.timestamp) - block.timestamp < 1 days;

                // This ensures that we checkpoint once at the beginning of the week and again for each user interaction
                // towards the end of the week to give an accurate final reading of the balance.
                if (alreadyCheckpointedThisWeek && !nearingEndOfWeek) {
                    return;
                }
            }
        }

        tokenState.timeCursor = uint64(block.timestamp);

        uint tokenBalance = token.balanceOf(address(this));
        uint newTokensToDistribute = tokenBalance - tokenState.cachedBalance;
        if (newTokensToDistribute == 0) return;
        require(tokenBalance <= type(uint128).max, "Maximum token balance exceeded");
        tokenState.cachedBalance = uint128(tokenBalance);

        uint firstIncompleteWeek = _roundEpochTime(lastTokenTime);
        uint nextWeek = 0;

        // Distribute `newTokensToDistribute` evenly across the time period from `lastTokenTime` to now.
        // These tokens are assigned to weeks proportionally to how much of this period falls into each week.
        mapping(uint => uint) storage tokensPerWeek = _tokensPerWeek[token];
        for (uint i = 0; i < 20;) {
            unchecked {
                // This is safe as we're incrementing a timestamp.
                nextWeek = firstIncompleteWeek + 1 weeks;
                if (block.timestamp < nextWeek) {
                    // `firstIncompleteWeek` is now the beginning of the current week, i.e. this is the final iteration.
                    if (timeSinceLastCheckpoint == 0 && block.timestamp == lastTokenTime) {
                        tokensPerWeek[firstIncompleteWeek] += newTokensToDistribute;
                    } else {
                        // block.timestamp >= lastTokenTime by definition.
                        tokensPerWeek[firstIncompleteWeek] += (newTokensToDistribute * (block.timestamp - lastTokenTime)) / timeSinceLastCheckpoint;
                    }
                    // As we've caught up to the present then we should now break.
                    break;
                } else {
                    // We've gone a full week or more without checkpointing so need to distribute tokens to previous weeks.
                    if (timeSinceLastCheckpoint == 0 && nextWeek == lastTokenTime) {
                        // It shouldn't be possible to enter this block
                        tokensPerWeek[firstIncompleteWeek] += newTokensToDistribute;
                    } else {
                        // nextWeek > lastTokenTime by definition.
                        tokensPerWeek[firstIncompleteWeek] += (newTokensToDistribute * (nextWeek - lastTokenTime)) / timeSinceLastCheckpoint;
                    }
                }

                // We've now "checkpointed" up to the beginning of next week so must update timestamps appropriately.
                lastTokenTime = nextWeek;
                firstIncompleteWeek = nextWeek;

                ++i;
            }
        }

        emit VeRevenueDistributor__TokenCheckpoint(token, newTokensToDistribute, lastTokenTime);
    }

    function _getClaimableToken(IERC20 token, TokenState memory tokenState, address user)
        internal
        view
        returns (uint amount, uint nextUserTokenWeekToClaim)
    {
        nextUserTokenWeekToClaim = _getUserTokenTimeCursor(user, token);

        // The first week which cannot be correctly claimed is the earliest of:
        // - A) The global or user time cursor (whichever is earliest), rounded up to the end of the week.
        // - B) The token time cursor, rounded down to the beginning of the week.
        //
        // This prevents the two failure modes:
        // - A) A user may claim a week for which we have not processed their balance, resulting in tokens being locked.
        // - B) A user may claim a week which then receives more tokens to be distributed. However the user has
        //      already claimed for that week so their share of these new tokens are lost.
        uint firstUnclaimableWeek =
            Math.min(_roundUpTimestamp(Math.min(_timeCursor, _userState[user].timeCursor)), _roundEpochTime(tokenState.timeCursor));

        mapping(uint => uint) storage tokensPerWeek = _tokensPerWeek[token];
        mapping(uint => uint) storage userBalanceAtTimestamp = _userBalanceAtTimestamp[user];

        amount;

        for (uint i = 0; i < 20;) {
            // We clearly cannot claim for `firstUnclaimableWeek` and so we break here.
            if (nextUserTokenWeekToClaim >= firstUnclaimableWeek) break;

            unchecked {
                amount += (tokensPerWeek[nextUserTokenWeekToClaim] * userBalanceAtTimestamp[nextUserTokenWeekToClaim])
                    / _veSupplyCache[nextUserTokenWeekToClaim];
                nextUserTokenWeekToClaim += 1 weeks;
                ++i;
            }
        }
    }

    /**
     * @dev Cache the `user`'s balance of `_votingEscrow` at the beginning of each new week
     */
    function _checkpointUserBalance(address user) internal {
        uint maxUserEpoch = _votingEscrow.userPointEpoch(user);

        // If user has no epochs then they have never locked vetoken.
        // They clearly will not then receive fees.
        if (maxUserEpoch == 0) return;

        UserState storage userState = _userState[user];

        // `nextWeekToCheckpoint` represents the timestamp of the beginning of the first week
        // which we haven't checkpointed the user's VotingEscrow balance yet.
        uint nextWeekToCheckpoint = userState.timeCursor;

        uint userEpoch;
        if (nextWeekToCheckpoint == 0) {
            // First checkpoint for user so need to do the initial binary search
            userEpoch = _votingEscrow.findTimestampUserEpoch(user, _startTime, 0, maxUserEpoch);
        } else {
            if (nextWeekToCheckpoint >= block.timestamp) {
                // User has checkpointed the current week already so perform early return.
                // This prevents a user from processing epochs created later in this week, however this is not an issue
                // as if a significant number of these builds up then the user will skip past them with a binary search.
                return;
            }

            // Otherwise use the value saved from last time
            userEpoch = userState.lastEpochCheckpointed;

            unchecked {
                // This optimizes a scenario common for power users, which have frequent `VotingEscrow` interactions in
                // the same week. We assume that any such user is also claiming fees every week, and so we only perform
                // a binary search here rather than integrating it into the main search algorithm, effectively skipping
                // most of the week's irrelevant checkpoints.
                // The slight tradeoff is that users who have multiple infrequent `VotingEscrow` interactions and also don't
                // claim frequently will also perform the binary search, despite it not leading to gas savings.
                if (maxUserEpoch - userEpoch > 20) {
                    userEpoch = _votingEscrow.findTimestampUserEpoch(user, nextWeekToCheckpoint, userEpoch, maxUserEpoch);
                }
            }
        }

        // Epoch 0 is always empty so bump onto the next one so that we start on a valid epoch.
        if (userEpoch == 0) {
            userEpoch = 1;
        }

        VotingEscrow.Point memory nextUserPoint = _votingEscrow.getUserPointHistory(user, userEpoch);

        // If this is the first checkpoint for the user, calculate the first week they're eligible for.
        // i.e. the timestamp of the first Thursday after they locked.
        // If this is earlier then the first distribution then fast forward to then.
        if (nextWeekToCheckpoint == 0) {
            // Disallow checkpointing before `startTime`.
            require(block.timestamp > _startTime, "Fee distribution has not started yet");
            nextWeekToCheckpoint = Math.max(_startTime, _roundUpTimestamp(nextUserPoint.ts));
            userState.startTime = uint64(nextWeekToCheckpoint);
        }

        // It's safe to increment `userEpoch` and `nextWeekToCheckpoint` in this loop as epochs and timestamps
        // are always much smaller than 2^256 and are being incremented by small values.
        VotingEscrow.Point memory currentUserPoint;
        for (uint i = 0; i < 50;) {
            unchecked {
                if (nextWeekToCheckpoint >= nextUserPoint.ts && userEpoch <= maxUserEpoch) {
                    // The week being considered is contained in a user epoch after that described by `currentUserPoint`.
                    // We then shift `nextUserPoint` into `currentUserPoint` and query the Point for the next user epoch.
                    // We do this in order to step though epochs until we find the first epoch starting after
                    // `nextWeekToCheckpoint`, making the previous epoch the one that contains `nextWeekToCheckpoint`.
                    userEpoch += 1;
                    currentUserPoint = nextUserPoint;
                    if (userEpoch > maxUserEpoch) {
                        nextUserPoint = VotingEscrow.Point(0, 0, 0, 0);
                    } else {
                        nextUserPoint = _votingEscrow.getUserPointHistory(user, userEpoch);
                    }
                } else {
                    // The week being considered lies inside the user epoch described by `oldUserPoint`
                    // we can then use it to calculate the user's balance at the beginning of the week.
                    if (nextWeekToCheckpoint >= block.timestamp) {
                        // Break if we're trying to cache the user's balance at a timestamp in the future.
                        // We only perform this check here to ensure that we can still process checkpoints created
                        // in the current week.
                        break;
                    }

                    int128 dt = SafeCast.toInt128(SafeCast.toInt256(nextWeekToCheckpoint - currentUserPoint.ts));
                    uint userBalance = currentUserPoint.bias > currentUserPoint.slope * dt
                        ? uint(SafeCast.toUint256(currentUserPoint.bias - currentUserPoint.slope * dt))
                        : 0;

                    // User's lock has expired and they haven't relocked yet.
                    if (userBalance == 0 && userEpoch > maxUserEpoch) {
                        nextWeekToCheckpoint = _roundUpTimestamp(block.timestamp);
                        break;
                    }

                    // User had a nonzero lock and so is eligible to collect fees.
                    _userBalanceAtTimestamp[user][nextWeekToCheckpoint] = userBalance;

                    nextWeekToCheckpoint += 1 weeks;
                }

                ++i;
            }
        }

        // We subtract off 1 from the userEpoch to step back once so that on the next attempt to checkpoint
        // the current `currentUserPoint` will be loaded as `nextUserPoint`. This ensures that we can't skip over the
        // user epoch containing `nextWeekToCheckpoint`.
        unchecked {
            // userEpoch > 0 so this is safe.
            userState.lastEpochCheckpointed = uint64(userEpoch - 1);
        }
        userState.timeCursor = uint64(nextWeekToCheckpoint);
    }

    /**
     * @dev Cache the totalSupply of VotingEscrow token at the beginning of each new week
     */
    function _checkpointTotalSupply() internal {
        uint nextWeekToCheckpoint = _timeCursor;
        uint weekStart = _roundEpochTime(block.timestamp);

        // We expect `timeCursor == weekStart + 1 weeks` when fully up to date.
        if (nextWeekToCheckpoint > weekStart || weekStart == block.timestamp) {
            // We've already checkpointed up to this week so perform early return
            return;
        }

        _votingEscrow.checkpoint();

        // Step through the each week and cache the total supply at beginning of week on this contract
        for (uint i = 0; i < 20; ++i) {
            if (nextWeekToCheckpoint > weekStart) break;

            _veSupplyCache[nextWeekToCheckpoint] = _votingEscrow.totalSupply(nextWeekToCheckpoint);

            // This is safe as we're incrementing a timestamp
            nextWeekToCheckpoint += 1 weeks;
        }
        // Update state to the end of the current week (`weekStart` + 1 weeks)
        _timeCursor = nextWeekToCheckpoint;
    }

    // Helper functions

    /**
     * @dev Wrapper around `_userTokenTimeCursor` which returns the start timestamp for `token`
     * if `user` has not attempted to interact with it previously.
     */
    function _getUserTokenTimeCursor(address user, IERC20 token) internal view returns (uint) {
        uint userTimeCursor = _userTokenTimeCursor[user][token];
        if (userTimeCursor > 0) return userTimeCursor;
        // This is the first time that the user has interacted with this token.
        // We then start from the latest out of either when `user` first locked vetoken or `token` was first checkpointed.
        return Math.max(_userState[user].startTime, _tokenState[token].startTime);
    }

    /**
     * @dev Rounds the provided timestamp down to the beginning of the previous week (Thurs 00:00 UTC)
     */
    function _roundEpochTime(uint timestamp) private pure returns (uint) {
        unchecked {
            // Division by zero or overflows are impossible here.
            return (timestamp / 1 weeks) * 1 weeks;
        }
    }

    /**
     * @dev Rounds the provided timestamp up to the beginning of the next week (Thurs 00:00 UTC)
     */
    function _roundUpTimestamp(uint timestamp) private pure returns (uint) {
        unchecked {
            // Overflows are impossible here for all realistic inputs.
            return _roundEpochTime(timestamp + 1 weeks - 1);
        }
    }
}
