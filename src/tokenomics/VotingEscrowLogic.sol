// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {CoreContract} from "../utils/CoreContract.sol";
import {EventEmitter} from "../utils/EventEmitter.sol";
import {Precision} from "../utils/Precision.sol";
import {Permission} from "../utils/access/Permission.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";

import {Router} from "../shared/Router.sol";

import {PuppetToken} from "../tokenomics/PuppetToken.sol";
import {PuppetVoteToken} from "./PuppetVoteToken.sol";
import {VotingEscrowStore} from "./store/VotingEscrowStore.sol";

uint constant MAXTIME = 365 * 2 days;

/// @title Token Voting Escrow
/// @notice lock tokens for a certain period to obtain governance voting power.
/// The lock duration is subject to a weighted average adjustment when additional tokens are locked for a new duration.
/// Upon unlocking, tokens enter a
/// vesting period, the duration of which is determined by the weighted average of the lock durations. The vesting
/// period is recalculated whenever
/// additional tokens are locked, incorporating the new amount and duration into the weighted average.
/// @dev The contract inherits from Permission and ERC20Votes to provide token locking and voting features.
/// It uses a weighted average mechanism to adjust lock durations and vesting periods.
contract VotingEscrowLogic is CoreContract {
    Router public immutable router;
    PuppetToken public immutable token;
    VotingEscrowStore public immutable store;
    PuppetVoteToken public immutable vToken;

    /// @notice Calculates the amount of tokens that can be claimed by the user.
    /// @param _user The address of the user whose claimable amount is to be calculated.
    /// @return The amount of tokens that can be claimed by the user.
    function getClaimable(address _user) external view returns (uint) {
        VotingEscrowStore.Vest memory _vest = store.getVest(_user);

        uint _timeElapsed = block.timestamp - _vest.lastAccruedTime;

        if (_timeElapsed > _vest.remainingDuration) {
            return _vest.accrued + _vest.amount;
        }

        return _vest.accrued + (_vest.amount * _timeElapsed / _vest.remainingDuration);
    }

    /// @notice Calculates the current vesting state for a given user.
    /// @param _user The address of the user whose vesting state is to be calculated.
    /// @return The current vesting state of the specified user.
    function getVestingCursor(address _user) public view returns (VotingEscrowStore.Vest memory) {
        VotingEscrowStore.Vest memory _vest = store.getVest(_user);

        uint _timeElapsed = block.timestamp - _vest.lastAccruedTime;

        if (_timeElapsed > _vest.remainingDuration) {
            return VotingEscrowStore.Vest({
                amount: 0,
                remainingDuration: 0,
                lastAccruedTime: block.timestamp,
                accrued: _vest.accrued + _vest.amount
            });
        }

        uint _accruedDelta = _timeElapsed * (_vest.amount / _vest.remainingDuration);

        return VotingEscrowStore.Vest({
            amount: _vest.amount - _accruedDelta,
            remainingDuration: _vest.remainingDuration - _timeElapsed,
            lastAccruedTime: block.timestamp,
            accrued: _vest.accrued + _accruedDelta
        });
    }

    function getDurationBonusMultiplier(uint durationBonusMultiplier, uint duration) internal pure returns (uint) {
        uint durationMultiplier = Precision.applyFactor(durationBonusMultiplier, MAXTIME);

        return Precision.toFactor(duration, durationMultiplier);
    }

    /// @notice Initializes the contract with the specified authority, router, and token.
    /// @param _authority The address of the authority contract for permission checks.
    /// @param _router The address of the router contract for token transfers.
    /// @param _token The address of the ERC20 token to be locked.
    constructor(
        IAuthority _authority,
        EventEmitter _eventEmitter,
        Router _router,
        PuppetToken _token,
        PuppetVoteToken _vToken,
        VotingEscrowStore _store
    ) CoreContract("Puppet Voting Power", "1", _authority, _eventEmitter) {
        router = _router;
        store = _store;
        vToken = _vToken;
        token = _token;
    }

    /// @notice Locks tokens for a user, granting them voting power and bonus rewards.
    /// @dev Emits a VotingEscrowLogic__Lock event on successful lock.
    /// @param depositor The address that provides the tokens to be locked.
    /// @param user The address for whom the tokens are locked.
    /// @param amount The amount of tokens to be locked.
    /// @param duration The duration for which the tokens are to be locked.
    function lock(address depositor, address user, uint amount, uint duration) external auth {
        if (amount == 0) revert VotingEscrowLogic__ZeroAmount();
        if (duration > MAXTIME) revert VotingEscrowLogic__ExceedMaxTime();

        VotingEscrowStore.Lock memory _lock = store.getLock(user);

        router.transfer(token, depositor, address(this), amount);

        uint durationMultiplier = getDurationBonusMultiplier(amount, duration);
        uint bonusAmount = Precision.applyFactor(durationMultiplier, amount);

        token.mint(address(this), bonusAmount);
        vToken.mint(user, amount + bonusAmount);

        uint _amountNext = _lock.amount + amount + bonusAmount;

        _lock.duration = (_lock.amount * _lock.duration + amount * duration) / _amountNext;
        _lock.amount = _amountNext;

        store.setLock(user, _lock);

        eventEmitter.log("VotingEscrowLogic__Lock", abi.encode(depositor, user, _lock));
    }

    /// @notice Begins the vesting process for a user's locked tokens.
    /// @dev Emits a VotingEscrowLogic__Vest event on successful vesting initiation.
    /// @param _user The address of the user whose tokens are to begin vesting.
    /// @param _receiver The address that will receive the vested tokens.
    /// @param _amount The amount of tokens to begin vesting.
    function vest(address _user, address _receiver, uint _amount) external auth {
        if (_amount == 0) revert VotingEscrowLogic__ZeroAmount();

        VotingEscrowStore.Lock memory _lock = store.getLock(_user);

        if (_amount > _lock.amount) {
            revert VotingEscrowLogic__ExceedingLockAmount(_lock.amount);
        }

        _lock.amount -= _amount;

        VotingEscrowStore.Vest memory _vest = getVestingCursor(_user);

        _vest.remainingDuration =
            (_vest.amount * _vest.remainingDuration + _amount * _lock.duration) / (_vest.amount + _amount);
        _vest.amount = _vest.amount + _amount;

        store.setLock(_user, _lock);
        store.setVest(_user, _vest);
        vToken.burn(_user, _amount);

        eventEmitter.log("VotingEscrowLogic__Vest", abi.encode(_user, _receiver, _vest));
    }

    /// @notice Allows a user to claim their vested tokens.
    /// @dev Emits a VotingEscrowLogic__Claim event on successful claim.
    /// @param _user The address of the user claiming their tokens.
    /// @param _receiver The address that will receive the claimed tokens.
    /// @param _amount The amount of tokens to be claimed.
    function claim(address _user, address _receiver, uint _amount) external auth {
        if (_amount == 0) revert VotingEscrowLogic__ZeroAmount();
        VotingEscrowStore.Vest memory _vest = getVestingCursor(_user);

        if (_amount > _vest.accrued) {
            revert VotingEscrowLogic__ExceedingAccruedAmount(_vest.accrued);
        }

        _vest.accrued -= _amount;
        store.setVest(_user, _vest);
        token.transfer(_receiver, _amount);

        eventEmitter.log("VotingEscrowLogic__Claim", abi.encode(_user, _receiver, _amount));
    }

    error VotingEscrowLogic__ZeroAmount();
    error VotingEscrowLogic__ExceedMaxTime();
    error VotingEscrowLogic__ExceedingAccruedAmount(uint accrued);
    error VotingEscrowLogic__ExceedingLockAmount(uint amount);
}
