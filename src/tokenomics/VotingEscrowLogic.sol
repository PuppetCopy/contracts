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

uint constant MAXTIME = 365 * 2 days;

/// @title VotingEscrowLogic
/// @notice lock tokens for a certain period to obtain governance voting power and bonus rewards based on the lock duration
/// The lock duration is subject to a weighted average adjustment when additional tokens are locked for a new duration.
/// Upon unlocking, tokens enter a vesting period, the duration of which is determined by the weighted average of the
/// lock durations. The vesting period is recalculated whenever
/// additional tokens are locked, incorporating the new amount and duration into the weighted average.
/// @dev The contract inherits from Permission which are used for access control for router contracts.
/// It uses a weighted average mechanism to adjust lock durations and vesting periods.
contract VotingEscrowLogic is CoreContract {
    /// @notice Struct to hold configuration parameters.
    struct Config {
        uint baseMultiplier;
    }

    /// @notice The configuration parameters for the RewardLogic
    Config public config;

    PuppetToken public immutable token;
    PuppetVoteToken public immutable vToken;
    VotingEscrowStore public immutable store;

    /// @notice Calculates the amount of tokens that can be claimed by the user.
    /// @param user The address of the user whose claimable amount is to be calculated.
    /// @return The amount of tokens that can be claimed by the user.
    function getClaimable(address user) external view returns (uint) {
        VotingEscrowStore.Vested memory vested = store.getVested(user);

        uint timeElapsed = block.timestamp - vested.lastAccruedTime;

        if (timeElapsed > vested.remainingDuration) {
            return vested.accrued + vested.amount;
        }

        return vested.accrued + (vested.amount * timeElapsed / vested.remainingDuration);
    }

    /// @notice Calculates the current vesting state for a given user.
    /// @param user The address of the user whose vesting state is to be calculated.
    /// @return The current vesting state of the specified user.
    function getVestingCursor(address user) public view returns (VotingEscrowStore.Vested memory) {
        VotingEscrowStore.Vested memory vested = store.getVested(user);

        uint timeElapsed = block.timestamp - vested.lastAccruedTime;

        if (timeElapsed > vested.remainingDuration) {
            return VotingEscrowStore.Vested({
                amount: 0,
                remainingDuration: 0,
                lastAccruedTime: block.timestamp,
                accrued: vested.accrued + vested.amount
            });
        }

        uint accruedDelta = timeElapsed * (vested.amount / vested.remainingDuration);

        return VotingEscrowStore.Vested({
            amount: vested.amount - accruedDelta,
            remainingDuration: vested.remainingDuration - timeElapsed,
            lastAccruedTime: block.timestamp,
            accrued: vested.accrued + accruedDelta
        });
    }

    // Exponential reward function
    function getDurationMultiplier(uint duration) public view returns (uint) {
        uint numerator = config.baseMultiplier * (duration ** 2);

        // The result is scaled up by the baseMultiplier to maintain precision
        return numerator / MAXTIME ** 2;
    }

    function getBonusAmount(uint amount, uint duration) public view returns (uint) {
        return Precision.applyFactor(getDurationMultiplier(duration), amount);
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

        setConfig(_config);
    }

    /// @notice Locks tokens for a user, granting them voting power and bonus rewards
    /// @dev Emits a VotingEscrowLogic__Lock event on successful lock.
    /// @param depositor The address that provides the tokens to be locked.
    /// @param user The address for whom the tokens are locked.
    /// @param amount  The amount of tokens to be locked.
    /// @param duration The duration for which the tokens are to be locked.
    function lock(address depositor, address user, uint amount, uint duration) external auth {
        if (amount == 0) revert VotingEscrowLogic__ZeroAmount();
        if (duration > MAXTIME) revert VotingEscrowLogic__ExceedMaxTime();

        store.transferIn(token, depositor, amount);

        uint bonusAmount = getBonusAmount(amount, duration);
        token.mint(address(this), bonusAmount);
        _vest(user, user, amount, duration);

        uint lockDuration = store.getLockDuration(user);
        uint vBalance = vToken.balanceOf(user);
        uint amountWithBonus = vBalance + bonusAmount;
        uint nextAmount = vBalance + amountWithBonus;
        uint nextDuration = (lockDuration * vBalance + duration * amountWithBonus) / nextAmount;

        store.setLockDuration(user, nextDuration);
        vToken.mint(user, amount);

        logEvent("lock()", abi.encode(depositor, user, nextAmount, nextDuration, bonusAmount));
    }

    /// @notice Begins the vesting process for a user's locked tokens.
    /// @param user The address of the user whose tokens are to begin vesting.
    /// @param receiver The address that will receive the vested tokens.
    /// @param amount The amount of tokens to begin vesting.
    function vest(address user, address receiver, uint amount) external auth {
        _vest(user, receiver, amount, store.getLockDuration(user));
    }

    /// @notice Allows a user to claim their vested tokens.
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

    function setConfig(Config memory _config) public auth {
        config = _config;

        logEvent("setConfig()", abi.encode(_config));
    }

    // internal
    function _vest(address user, address receiver, uint amount, uint duration) internal {
        if (duration == 0) revert VotingEscrowLogic__NothingLocked();
        if (amount == 0) revert VotingEscrowLogic__ZeroBalance();

        VotingEscrowStore.Vested memory vested = getVestingCursor(user);

        uint amountNext = vested.amount + amount;

        vested.remainingDuration = (vested.amount * vested.remainingDuration + amount * duration) / amountNext;
        vested.amount = amountNext;

        store.setVested(user, vested);
        vToken.burn(user, amount);

        logEvent("vest()", abi.encode(user, receiver, vested));
    }

    error VotingEscrowLogic__ZeroAmount();
    error VotingEscrowLogic__NothingLocked();
    error VotingEscrowLogic__ZeroBalance();
    error VotingEscrowLogic__ExceedMaxTime();
    error VotingEscrowLogic__ExceedingAccruedAmount(uint accrued);
}
