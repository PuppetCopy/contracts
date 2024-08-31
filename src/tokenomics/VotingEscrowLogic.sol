// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {PuppetToken} from "../tokenomics/PuppetToken.sol";
import {CoreContract} from "../utils/CoreContract.sol";
import {EventEmitter} from "../utils/EventEmitter.sol";
import {Precision} from "../utils/Precision.sol";
import {Permission} from "../utils/access/Permission.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {PuppetVoteToken} from "./PuppetVoteToken.sol";
import {VotingEscrowStore} from "./store/VotingEscrowStore.sol";

/// @title VotingEscrowLogic
/// @notice Manages the locking of tokens to provide users with governance voting power and time-based rewards.
/// This contract handles the logic for token vesting and voting power accrual based on the duration of token locks.
/// @dev Inherits from CoreContract and utilizes a separate VotingEscrowStore for state management.
/// It implements a weighted average mechanism for lock durations and vesting periods to calculate rewards.
contract VotingEscrowLogic is CoreContract {
    uint constant MAXTIME = 63120000; // 2 years

    /// @notice Struct to hold configuration parameters.
    struct Config {
        uint baseMultiplier;
    }

    /// @notice The configuration parameters for the RewardLogic
    Config public config;

    PuppetToken public immutable token;
    PuppetVoteToken public immutable vToken;
    VotingEscrowStore public immutable store;

    /// @notice Computes the current vesting state for a user, updating the amount and remaining duration.
    /// @dev Returns a Vested struct reflecting the state after accounting for the time elapsed since the last accrual.
    /// @param user The address of the user whose vesting state is to be calculated.
    /// @return vested The updated vesting state for the user.
    function getVestingCursor(address user) public view returns (VotingEscrowStore.Vested memory vested) {
        vested = store.getVested(user);
        uint timeElapsed = block.timestamp - vested.lastAccruedTime;
        uint accruedDelta = timeElapsed >= vested.remainingDuration
            ? vested.amount
            : timeElapsed * vested.amount / vested.remainingDuration;

        vested.remainingDuration = timeElapsed >= vested.remainingDuration ? 0 : vested.remainingDuration - timeElapsed;
        vested.amount -= accruedDelta;
        vested.accrued += accruedDelta;

        vested.lastAccruedTime = block.timestamp;

        return vested;
    }

    /// @notice Retrieves the claimable token amount for a given user, considering their vested tokens and time elapsed.
    /// @dev The claimable amount is a sum of already accrued tokens and a portion of the locked tokens based on time
    /// elapsed.
    /// @param user The address of the user whose claimable amount is to be calculated.
    /// @return The amount of tokens that can be claimed by the user.
    function getClaimable(address user) external view returns (uint) {
        return getVestingCursor(user).accrued;
    }

    /// @notice Calculates the multiplier for rewards based on the lock duration.
    /// @dev The multiplier follows an exponential scale to incentivize longer lock durations.
    /// @param duration The lock duration in seconds.
    /// @return The calculated duration multiplier.
    function calcDurationMultiplier(uint duration) public view returns (uint) {
        uint numerator = config.baseMultiplier * duration ** 2;

        return numerator / MAXTIME ** 2;
    }

    /// @notice Determines the bonus amount of tokens to be minted based on the amount locked and the duration.
    /// @dev Applies the duration multiplier to the locked amount to calculate the bonus.
    /// @param amount The amount of tokens locked.
    /// @param duration The duration for which the tokens are locked.
    /// @return The bonus amount of tokens.
    function getVestedBonus(uint amount, uint duration) public view returns (uint) {
        return Precision.applyFactor(calcDurationMultiplier(duration), amount);
    }

    /// @notice Initializes the contract with the specified authority, router, and token.
    /// @param _authority The address of the authority contract for permission checks.
    /// @param _token The address of the ERC20 token to be locked.
    constructor(
        IAuthority _authority,
        EventEmitter _eventEmitter,
        VotingEscrowStore _store,
        PuppetToken _token,
        PuppetVoteToken _vToken,
        Config memory _config
    ) CoreContract("VotingEscrowLogic", "1", _authority, _eventEmitter) {
        store = _store;
        token = _token;
        vToken = _vToken;

        _setConfig(_config);
    }

    /// @notice Locks tokens on behalf of a user, granting them voting power and bonus rewards.
    /// the bonus reward are minted to enter the vesting schedule.
    /// @dev Locks the tokens, mints bonus tokens, and updates the user's vesting schedule.
    /// Emits a lock event upon successful execution.
    /// @param depositor The address providing the tokens to be locked.
    /// @param user The address for whom the tokens are locked.
    /// @param amount The amount of tokens to be locked.
    /// @param duration The duration for which the tokens are to be locked.
    function lock(address depositor, address user, uint amount, uint duration) external auth {
        if (amount == 0) revert VotingEscrowLogic__ZeroAmount();
        if (duration > MAXTIME) revert VotingEscrowLogic__ExceedMaxTime();

        uint bonusAmount = getVestedBonus(amount, duration);

        store.transferIn(token, depositor, amount);
        token.mint(address(store), bonusAmount);
        store.syncTokenBalance(token);

        _vest(user, user, bonusAmount, duration);

        uint vBalance = vToken.balanceOf(user);
        uint nextAmount = vBalance + amount;
        uint nextDuration = (vBalance * store.getLockDuration(user) + amount * duration) / nextAmount;

        store.setLockDuration(user, nextDuration);
        vToken.mint(user, amount);

        logEvent("lock()", abi.encode(depositor, user, nextAmount, nextDuration));
    }

    /// @notice Initiates the vesting process for a user's locked tokens.
    /// @dev Updates the user's vesting schedule and burns the corresponding voting tokens.
    /// @param user The address of the user whose tokens are to begin vesting.
    /// @param receiver The address that will receive the vested tokens.
    /// @param amount The amount of tokens to begin vesting.
    function vest(address user, address receiver, uint amount) external auth {
        vToken.burn(user, amount);

        _vest(user, receiver, amount, store.getLockDuration(user));
    }

    /// @notice Allows a user to claim their vested tokens.
    /// @dev Transfers the claimed tokens to the receiver and updates the user's vesting schedule.
    /// @param user The address of the user claiming their tokens.
    /// @param receiver The address that will receive the claimed tokens.
    /// @param amount The amount of tokens to be claimed.
    function claim(address user, address receiver, uint amount) external auth {
        if (amount == 0) revert VotingEscrowLogic__ZeroAmount();
        VotingEscrowStore.Vested memory vested = getVestingCursor(user);

        if (amount > vested.accrued) {
            revert VotingEscrowLogic__ExceedingAccruedAmount(vested.accrued);
        }

        vested.accrued -= amount;
        store.setVested(user, vested);
        store.transferOut(token, receiver, amount);

        logEvent("claim()", abi.encode(user, receiver, amount));
    }

    // governance

    /// @notice Set the mint rate limit for the token.
    /// @param _config The new rate limit configuration.
    function setConfig(Config calldata _config) external auth {
        _setConfig(_config);
    }

    /// @notice Sets the configuration parameters for the contract.
    /// @dev Can only be called by an authorized entity. Updates the contract's configuration.
    /// @param _config The new configuration parameters.
    function _setConfig(Config memory _config) internal {
        config = _config;
        logEvent("setConfig()", abi.encode(_config));
    }

    // internal
    function _vest(address user, address receiver, uint amount, uint duration) internal {
        if (amount == 0) revert VotingEscrowLogic__ZeroAmount();

        VotingEscrowStore.Vested memory vested = getVestingCursor(user);

        uint amountNext = vested.amount + amount;

        vested.remainingDuration = (vested.amount * vested.remainingDuration + amount * duration) / amountNext;
        vested.amount = amountNext;

        store.setVested(user, vested);

        logEvent("vest()", abi.encode(user, receiver, vested));
    }

    error VotingEscrowLogic__ZeroAmount();
    error VotingEscrowLogic__ExceedMaxTime();
    error VotingEscrowLogic__ExceedingAccruedAmount(uint accrued);
}
