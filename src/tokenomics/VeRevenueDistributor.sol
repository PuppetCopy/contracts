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
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";

import {VotingEscrow} from "./VotingEscrow.sol";
import {Router} from "../utils/Router.sol";
import {VeRevenueDistributor} from "./VeRevenueDistributor.sol";

/**
 * @title Fee Distributor
 * @notice Distributes any tokens transferred to the contract (e.g. Protocol fees and any BAL emissions) among veBAL
 * holders proportionally based on a snapshot of the week at which the tokens are sent to the FeeDistributor contract.
 * @dev Supports distributing arbitrarily many different tokens. In order to start distributing a new token to veBAL
 * holders simply transfer the tokens to the `FeeDistributor` contract and then call `checkpointToken`.
 * slightly modified from
 * https://github.com/balancer/balancer-v2-monorepo/blob/master/pkg/liquidity-mining/contracts/fee-distribution/FeeDistributor.sol
 */
contract VeRevenueDistributor is Auth, EIP712, ReentrancyGuard {
    event VeRevenueDistributor__TokenCheckpoint(IERC20 token, uint amount, uint lastCheckpointTimestamp);
    event VeRevenueDistributor__TokensClaim(address from, address to, IERC20 token, uint amount, uint userTokenTimeCursor);

    // `startTime` and `timeCursor` are both timestamps so comfortably fit in a uint64.
    // `cachedBalance` will comfortably fit the total supply of any meaningful token.
    // Should more than 2^128 tokens be sent to this contract then checkpointing this token will fail until enough
    // tokens have been claimed to bring the total balance back below 2^128.
    struct TokenState {
        uint64 startTime;
        uint64 timeCursor;
        uint cachedBalance;
    }

    struct UserState {
        uint64 startTime;
        uint64 timeCursor;
        uint128 lastEpochCheckpointed;
    }

    VotingEscrow public immutable votingEscrow;
    Router immutable router;
    uint immutable startTime;

    uint public timeCursor;

    mapping(uint => uint) _veSupplyCache;
    mapping(IERC20 => TokenState) _tokenState;
    mapping(IERC20 => mapping(uint => uint)) _tokensPerWeek;

    mapping(address => UserState) _userState;
    mapping(address => mapping(uint => uint)) _userBalanceAtTimestamp;
    mapping(address => mapping(IERC20 => uint)) _userTokenTimeCursor;

    /**
     * @notice Returns the user-level time cursor representing the most earliest uncheckpointed week.
     * @param _user - The address of the user to query.
     */
    function getUserState(address _user) external view returns (UserState memory) {
        return _userState[_user];
    }

    /**
     * @notice Returns the token-level time cursor storing the timestamp at up to which tokens have been distributed.
     * @param _token - The ERC20 token address to query.
     */
    function getTokenState(IERC20 _token) external view returns (TokenState memory) {
        return _tokenState[_token];
    }

    /**
     * @notice Returns the user-level time cursor storing the timestamp of the latest token distribution claimed.
     * @param _user - The address of the user to query.
     * @param _token - The ERC20 token address to query.
     */
    function getUserTokenTimeCursor(address _user, IERC20 _token) external view returns (uint) {
        return _getUserTokenTimeCursor(_user, _token);
    }

    /**
     * @notice Returns the user's cached balance of veBAL as of the provided timestamp.
     * @dev Only timestamps which fall on Thursdays 00:00:00 UTC will return correct values.
     * This function requires `user` to have been checkpointed past `timestamp` so that their balance is cached.
     * @param _user - The address of the user of which to read the cached balance of.
     * @param _timestamp - The timestamp at which to read the `user`'s cached balance at.
     */
    function getUserBalanceAtTimestamp(address _user, uint _timestamp) external view returns (uint) {
        return _userBalanceAtTimestamp[_user][_timestamp];
    }

    /**
     * @notice Returns the cached total supply of veBAL as of the provided timestamp.
     * @dev Only timestamps which fall on Thursdays 00:00:00 UTC will return correct values.
     * This function requires the contract to have been checkpointed past `timestamp` so that the supply is cached.
     * @param _timestamp - The timestamp at which to read the cached total supply at.
     */
    function getTotalSupplyAtTimestamp(uint _timestamp) external view returns (uint) {
        return _veSupplyCache[_timestamp];
    }

    /**
     * @notice Returns the amount of `token` which the FeeDistributor received in the week beginning at `timestamp`.
     * @param _token - The ERC20 token address to query.
     * @param _timestamp - The timestamp corresponding to the beginning of the week of interest.
     */
    function getTokensDistributedInWeek(IERC20 _token, uint _timestamp) external view returns (uint) {
        return _tokensPerWeek[_token][_timestamp];
    }

    /**
     * @notice Returns the amount of `token` which the FeeDistributor received in the current week.
     * @param _token - The ERC20 token address to query.
     * @param _timestamp - The timestamp corresponding to the beginning of the week of interest.
     * @return The amount of `token` received in the current week.
     */
    function getTokensPerWeek(IERC20 _token, uint _timestamp) external view returns (uint) {
        return _tokensPerWeek[_token][_timestamp];
    }

    constructor(Authority _authority, VotingEscrow _votingEscrow, Router _router, uint _startTime)
        EIP712("FeeDistributor", "1")
        Auth(address(0), _authority)
    {
        votingEscrow = _votingEscrow;
        router = _router;

        _startTime = _roundDownTimestamp(_startTime);
        uint currentWeek = _roundDownTimestamp(block.timestamp);
        require(_startTime >= currentWeek, "Cannot start before current week");

        startTime = _startTime;
        timeCursor = _startTime;
    }

    // Depositing

    /**
     * @notice Deposits tokens to be distributed in the current week.
     * @dev Sending tokens directly to the FeeDistributor instead of using `depositToken` may result in tokens being
     * retroactively distributed to past weeks, or for the distribution to carry over to future weeks.
     *
     * If for some reason `depositToken` cannot be called, in order to ensure that all tokens are correctly distributed
     * manually call `checkpointToken` before and after the token transfer.
     * @param _token - The ERC20 token address to distribute.
     * @param _amount - The amount of tokens to deposit.
     */
    function depositToken(IERC20 _token, uint _amount) external nonReentrant {
        _checkpointToken(_token, false);
        router.transfer(_token, msg.sender, address(this), _amount);
        _checkpointToken(_token, true);
    }

    function depositTokenFrom(IERC20 token, address from, uint amount) external nonReentrant requiresAuth {
        _checkpointToken(token, false);
        router.transfer(token, from, address(this), amount);
        _checkpointToken(token, true);
    }

    /**
     * @notice Deposits tokens to be distributed in the current week.
     * @dev A version of `depositToken` which supports depositing multiple `tokens` at once.
     * See `depositToken` for more details.
     * @param _tokens - An array of ERC20 token addresses to distribute.
     * @param _amounts - An array of token amounts to deposit.
     */
    function depositTokens(IERC20[] calldata _tokens, uint[] calldata _amounts) external nonReentrant {
        // InputHelpers.ensureInputLengthMatch(tokens.length, amounts.length);
        if (_tokens.length != _amounts.length) revert VeRevenueDistributor__MismatchedArrayLengths();

        uint length = _tokens.length;
        for (uint i = 0; i < length; ++i) {
            _checkpointToken(_tokens[i], false);
            router.transfer(_tokens[i], msg.sender, address(this), _amounts[i]);
            _checkpointToken(_tokens[i], true);
        }
    }

    // Checkpointing

    /**
     * @notice Caches the total supply of veBAL at the beginning of each week.
     * This function will be called automatically before claiming tokens to ensure the contract is properly updated.
     */
    function checkpoint() external nonReentrant {
        _checkpointTotalSupply();
    }

    /**
     * @notice Caches the user's balance of veBAL at the beginning of each week.
     * This function will be called automatically before claiming tokens to ensure the contract is properly updated.
     * @param _user - The address of the user to be checkpointed.
     */
    function checkpointUser(address _user) external nonReentrant {
        _checkpointUserBalance(_user);
    }

    /**
     * @notice Assigns any newly-received tokens held by the FeeDistributor to weekly distributions.
     * @dev Any `token` balance held by the FeeDistributor above that which is returned by `getTokenLastBalance`
     * will be distributed evenly across the time period since `token` was last checkpointed.
     *
     * This function will be called automatically before claiming tokens to ensure the contract is properly updated.
     * @param _token - The ERC20 token address to be checkpointed.
     */
    function checkpointToken(IERC20 _token) external nonReentrant {
        _checkpointToken(_token, true);
    }

    /**
     * @notice Assigns any newly-received tokens held by the FeeDistributor to weekly distributions.
     * @dev A version of `checkpointToken` which supports checkpointing multiple tokens.
     * See `checkpointToken` for more details.
     * @param _tokens - An array of ERC20 token addresses to be checkpointed.
     */
    function checkpointTokens(IERC20[] calldata _tokens) external nonReentrant {
        uint tokensLength = _tokens.length;
        for (uint i = 0; i < tokensLength; ++i) {
            _checkpointToken(_tokens[i], true);
        }
    }

    // Claiming

    /**
     * @notice Claims all pending distributions of the provided token for a user.
     * @dev It's not necessary to explicitly checkpoint before calling this function, it will ensure the FeeDistributor
     * is up to date before calculating the amount of tokens to be claimed.
     * @param _token - The ERC20 token address to be claimed.
     * @param _receiver - The address which will receive the claimed tokens.
     * @return The amount of `token` sent to `user` as a result of claiming.
     */
    function claim(IERC20 _token, address _receiver) external nonReentrant returns (uint) {
        _checkpointTotalSupply();
        _checkpointUserBalance(msg.sender);
        _checkpointToken(_token, false);

        uint amount = _claimToken(_receiver, _token);
        return amount;
    }

    /**
     * @notice Claims a number of tokens on behalf of a user.
     * @dev A version of `claimToken` which supports claiming multiple `tokens` on behalf of `user`.
     * See `claimToken` for more details.
     * @param _tokenList - An array of ERC20 token addresses to be claimed.
     * @param _receiver - The address which will receive the claimed tokens.
     * @return An array of the amounts of each token in `tokens` sent to `user` as a result of claiming.
     */
    function claimList(IERC20[] calldata _tokenList, address _receiver) external nonReentrant returns (uint[] memory) {
        _checkpointTotalSupply();
        _checkpointUserBalance(msg.sender);

        uint tokensLength = _tokenList.length;
        uint[] memory amounts = new uint[](tokensLength);
        for (uint i = 0; i < tokensLength; ++i) {
            _checkpointToken(_tokenList[i], false);
            amounts[i] = _claimToken(_receiver, _tokenList[i]);
        }

        return amounts;
    }

    // Internal functions

    /**
     * @dev It is required that both the global, token and user state have been properly checkpointed
     * before calling this function.
     */
    function _claimToken(address _user, IERC20 _token) internal returns (uint) {
        TokenState storage tokenState = _tokenState[_token];
        uint nextUserTokenWeekToClaim = _getUserTokenTimeCursor(_user, _token);

        // The first week which cannot be correctly claimed is the earliest of:
        // - A) The global or user time cursor (whichever is earliest), rounded up to the end of the week.
        // - B) The token time cursor, rounded down to the beginning of the week.
        //
        // This prevents the two failure modes:
        // - A) A user may claim a week for which we have not processed their balance, resulting in tokens being locked.
        // - B) A user may claim a week which then receives more tokens to be distributed. However the user has
        //      already claimed for that week so their share of these new tokens are lost.
        uint firstUnclaimableWeek = Math.min(
            _roundUpTimestamp(Math.min(timeCursor, _userState[_user].timeCursor)), //
            _roundDownTimestamp(tokenState.timeCursor)
        );

        mapping(uint => uint) storage tokensPerWeek = _tokensPerWeek[_token];
        mapping(uint => uint) storage userBalanceAtTimestamp = _userBalanceAtTimestamp[_user];

        uint amount;
        for (uint i = 0; i < 20; ++i) {
            // We clearly cannot claim for `firstUnclaimableWeek` and so we break here.
            if (nextUserTokenWeekToClaim >= firstUnclaimableWeek) break;

            amount += (tokensPerWeek[nextUserTokenWeekToClaim] * userBalanceAtTimestamp[nextUserTokenWeekToClaim])
                / _veSupplyCache[nextUserTokenWeekToClaim];
            nextUserTokenWeekToClaim += 1 weeks;
        }
        // Update the stored user-token time cursor to prevent this user claiming this week again.
        _userTokenTimeCursor[_user][_token] = nextUserTokenWeekToClaim;

        if (amount > 0) {
            // For a token to be claimable it must have been added to the cached balance so this is safe.
            tokenState.cachedBalance = uint128(tokenState.cachedBalance - amount);
            _token.transfer(_user, amount);
            // emit TokensClaimed(user, token, amount, nextUserTokenWeekToClaim);
            emit VeRevenueDistributor__TokensClaim(msg.sender, _user, _token, amount, nextUserTokenWeekToClaim);
        }

        return amount;
    }

    /**
     * @dev Calculate the amount of `token` to be distributed to `_votingEscrow` holders since the last checkpoint.
     */
    function _checkpointToken(IERC20 _token, bool _force) internal {
        TokenState storage tokenState = _tokenState[_token];
        uint lastTokenTime = tokenState.timeCursor;
        uint timeSinceLastCheckpoint;
        if (lastTokenTime == 0) {
            // Prevent someone from assigning tokens to an inaccessible week.
            require(block.timestamp > startTime, "Fee distribution has not started yet");

            // If it's the first time we're checkpointing this token then start distributing from now.
            // Also mark at which timestamp users should start attempts to claim this token from.
            lastTokenTime = block.timestamp;
            tokenState.startTime = uint64(_roundDownTimestamp(block.timestamp));
        } else {
            timeSinceLastCheckpoint = block.timestamp - lastTokenTime;

            if (!_force) {
                // Checkpointing N times within a single week is completely equivalent to checkpointing once at the end.
                // We then want to get as close as possible to a single checkpoint every Wed 23:59 UTC to save gas.

                // We then skip checkpointing if we're in the same week as the previous checkpoint.
                bool alreadyCheckpointedThisWeek = _roundDownTimestamp(block.timestamp) == _roundDownTimestamp(lastTokenTime);
                // However we want to ensure that all of this week's fees are assigned to the current week without
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

        uint tokenBalance = _token.balanceOf(address(this));
        uint newTokensToDistribute = tokenBalance - tokenState.cachedBalance;
        if (newTokensToDistribute == 0) return;
        require(tokenBalance <= type(uint128).max, "Maximum token balance exceeded");
        tokenState.cachedBalance = uint128(tokenBalance);

        uint firstIncompleteWeek = _roundDownTimestamp(lastTokenTime);
        uint nextWeek = 0;

        // Distribute `newTokensToDistribute` evenly across the time period from `lastTokenTime` to now.
        // These tokens are assigned to weeks proportionally to how much of this period falls into each week.
        mapping(uint => uint) storage tokensPerWeek = _tokensPerWeek[_token];
        for (uint i = 0; i < 20; ++i) {
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
        }

        emit VeRevenueDistributor__TokenCheckpoint(_token, newTokensToDistribute, lastTokenTime);
    }

    /**
     * @dev Cache the `user`'s balance of `_votingEscrow` at the beginning of each new week
     */
    function _checkpointUserBalance(address _user) internal {
        uint _maxUserEpoch = votingEscrow.userPointEpoch(_user);

        // If user has no epochs then they have never locked veBAL.
        // They clearly will not then receive fees.
        if (_maxUserEpoch == 0) return;

        UserState storage userState = _userState[_user];

        // `nextWeekToCheckpoint` represents the timestamp of the beginning of the first week
        // which we haven't checkpointed the user's VotingEscrow balance yet.
        uint nextWeekToCheckpoint = userState.timeCursor;
        uint userEpoch;
        if (nextWeekToCheckpoint == 0) {
            // First checkpoint for user so need to do the initial binary search
            userEpoch = votingEscrow.findTimestampUserEpoch(_user, startTime, 0, _maxUserEpoch);
        } else {
            if (nextWeekToCheckpoint >= block.timestamp) {
                // User has checkpointed the current week already so perform early return.
                // This prevents a user from processing epochs created later in this week, however this is not an issue
                // as if a significant number of these builds up then the user will skip past them with a binary search.
                return;
            }

            // Otherwise use the value saved from last time
            userEpoch = userState.lastEpochCheckpointed;

            // This optimizes a scenario common for power users, which have frequent `VotingEscrow` interactions in
            // the same week. We assume that any such user is also claiming fees every week, and so we only perform
            // a binary search here rather than integrating it into the main search algorithm, effectively skipping
            // most of the week's irrelevant checkpoints.
            // The slight tradeoff is that users who have multiple infrequent `VotingEscrow` interactions and also don't
            // claim frequently will also perform the binary search, despite it not leading to gas savings.
            if (_maxUserEpoch - userEpoch > 20) {
                userEpoch = votingEscrow.findTimestampUserEpoch(_user, nextWeekToCheckpoint, userEpoch, _maxUserEpoch);
            }
        }

        // Epoch 0 is always empty so bump onto the next one so that we start on a valid epoch.
        if (userEpoch == 0) {
            userEpoch = 1;
        }

        VotingEscrow.Point memory nextUserPoint = votingEscrow.getUserPointHistory(_user, userEpoch);

        // If this is the first checkpoint for the user, calculate the first week they're eligible for.
        // i.e. the timestamp of the first Thursday after they locked.
        // If this is earlier then the first distribution then fast forward to then.
        if (nextWeekToCheckpoint == 0) {
            // Disallow checkpointing before `startTime`.
            require(block.timestamp > startTime, "Fee distribution has not started yet");
            nextWeekToCheckpoint = Math.max(startTime, _roundUpTimestamp(nextUserPoint.ts));
            userState.startTime = uint64(nextWeekToCheckpoint);
        }

        // It's safe to increment `userEpoch` and `nextWeekToCheckpoint` in this loop as epochs and timestamps
        // are always much smaller than 2^256 and are being incremented by small values.
        VotingEscrow.Point memory currentUserPoint;
        for (uint i = 0; i < 50; ++i) {
            if (nextWeekToCheckpoint >= nextUserPoint.ts && userEpoch <= _maxUserEpoch) {
                // The week being considered is contained in a user epoch after that described by `currentUserPoint`.
                // We then shift `nextUserPoint` into `currentUserPoint` and query the Point for the next user epoch.
                // We do this in order to step though epochs until we find the first epoch starting after
                // `nextWeekToCheckpoint`, making the previous epoch the one that contains `nextWeekToCheckpoint`.
                userEpoch += 1; 
                currentUserPoint = nextUserPoint;
                if (userEpoch > _maxUserEpoch) {
                    nextUserPoint = VotingEscrow.Point(0, 0, 0, 0);
                } else {
                    nextUserPoint = votingEscrow.getUserPointHistory(_user, userEpoch);
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

                int128 dt = int128(int(nextWeekToCheckpoint - currentUserPoint.ts));
                uint userBalance =
                    currentUserPoint.bias > currentUserPoint.slope * dt ? uint(int(currentUserPoint.bias - currentUserPoint.slope * dt)) : 0;

                // User's lock has expired and they haven't relocked yet.
                if (userBalance == 0 && userEpoch > _maxUserEpoch) {
                    nextWeekToCheckpoint = _roundUpTimestamp(block.timestamp);
                    break;
                }

                // User had a nonzero lock and so is eligible to collect fees.
                _userBalanceAtTimestamp[_user][nextWeekToCheckpoint] = userBalance;

                nextWeekToCheckpoint += 1 weeks;
            }
        }

        // We subtract off 1 from the userEpoch to step back once so that on the next attempt to checkpoint
        // the current `currentUserPoint` will be loaded as `nextUserPoint`. This ensures that we can't skip over the
        // user epoch containing `nextWeekToCheckpoint`.
        // userEpoch > 0 so this is safe.
        userState.lastEpochCheckpointed = uint64(userEpoch - 1);
        userState.timeCursor = uint64(nextWeekToCheckpoint);
    }

    /**
     * @dev Cache the totalSupply of VotingEscrow token at the beginning of each new week
     */
    function _checkpointTotalSupply() internal {
        uint nextWeekToCheckpoint = timeCursor;
        uint weekStart = _roundDownTimestamp(block.timestamp);

        // We expect `timeCursor == weekStart + 1 weeks` when fully up to date.
        if (nextWeekToCheckpoint > weekStart || weekStart == block.timestamp) {
            // We've already checkpointed up to this week so perform early return
            return;
        }

        votingEscrow.checkpoint();

        // Step through the each week and cache the total supply at beginning of week on this contract
        for (uint i = 0; i < 20; ++i) {
            if (nextWeekToCheckpoint > weekStart) break;

            _veSupplyCache[nextWeekToCheckpoint] = votingEscrow.totalSupply(nextWeekToCheckpoint);

            // This is safe as we're incrementing a timestamp
            nextWeekToCheckpoint += 1 weeks;
        }
        // Update state to the end of the current week (`weekStart` + 1 weeks)
        timeCursor = nextWeekToCheckpoint;
    }
    // Helper functions

    /**
     * @dev Wrapper around `_userTokenTimeCursor` which returns the start timestamp for `token`
     * if `user` has not attempted to interact with it previously.
     */
    function _getUserTokenTimeCursor(address _user, IERC20 _token) internal view returns (uint) {
        uint userTimeCursor = _userTokenTimeCursor[_user][_token];
        if (userTimeCursor > 0) return userTimeCursor;
        // This is the first time that the user has interacted with this token.
        // We then start from the latest out of either when `user` first locked veBAL or `token` was first checkpointed.
        return Math.max(_userState[_user].startTime, _tokenState[_token].startTime);
    }

    /**
     * @dev Rounds the provided timestamp down to the beginning of the previous week (Thurs 00:00 UTC)
     */
    function _roundDownTimestamp(uint _timestamp) private pure returns (uint) {
        // Division by zero or overflows are impossible here.
        return (_timestamp / 1 weeks) * 1 weeks;
    }

    /**
     * @dev Rounds the provided timestamp up to the beginning of the next week (Thurs 00:00 UTC)
     */
    function _roundUpTimestamp(uint _timestamp) private pure returns (uint) {
        // Overflows are impossible here for all realistic inputs.
        return _roundDownTimestamp(_timestamp + 604799);
    }

    error VeRevenueDistributor__MismatchedArrayLengths();

    event Log(uint value); // TODO remove
    event LogAddress(address addr); // TODO remove
}
