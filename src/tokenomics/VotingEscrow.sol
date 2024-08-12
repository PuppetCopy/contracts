// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IAuthority} from "src/utils/interfaces/IAuthority.sol";
import {Permission} from "src/utils/access/Permission.sol";
import {Router} from "src/shared/Router.sol";

uint constant MAXTIME = 365 * 2 days;

/// @title Token Voting Escrow
/// @notice lock tokens for a certain period to obtain governance voting power.
/// The lock duration is subject to a weighted average adjustment when additional tokens are locked for a new duration. Upon unlocking, tokens enter a
/// vesting period, the duration of which is determined by the weighted average of the lock durations. The vesting period is recalculated whenever
/// additional tokens are locked, incorporating the new amount and duration into the weighted average.
/// @dev The contract inherits from Permission and ERC20Votes to provide token locking and voting features.
/// It uses a weighted average mechanism to adjust lock durations and vesting periods.
contract VotingEscrow is Permission, ERC20Votes {
    event VotingEscrow__Lock(address indexed depositor, address indexed user, Lock lock);
    event VotingEscrow__Vest(address indexed user, address indexed receiver, Vest vest);
    event VotingEscrow__Claim(address indexed user, address indexed receiver, uint amount);

    struct Lock {
        uint amount;
        uint duration;
    }

    struct Vest {
        uint amount;
        uint remainingDuration;
        uint lastAccruedTime;
        uint accrued;
    }

    mapping(address => Lock) public lockMap;
    mapping(address => Vest) public vestMap;

    Router public immutable router;
    IERC20 public immutable token;

    /// @notice Retrieves the lock information for a given user.
    /// @param _user The address of the user whose lock information is to be retrieved.
    /// @return The lock information of the specified user.
    function getLock(address _user) external view returns (Lock memory) {
        return lockMap[_user];
    }

    /// @notice Retrieves the vesting information for a given user.
    /// @param _user The address of the user whose vesting information is to be retrieved.
    /// @return The vesting information of the specified user.
    function getVest(address _user) external view returns (Vest memory) {
        return vestMap[_user];
    }

    /// @notice Initializes the contract with the specified authority, router, and token.
    /// @param _authority The address of the authority contract for permission checks.
    /// @param _router The address of the router contract for token transfers.
    /// @param _token The address of the ERC20 token to be locked.
    constructor(IAuthority _authority, Router _router, IERC20 _token)
        Permission(_authority)
        ERC20("Puppet Voting Power", "vePUPPET")
        EIP712("Voting Escrow", "1")
    {
        router = _router;
        token = _token;
    }

    /// @notice Calculates the amount of tokens that can be claimed by the user.
    /// @param _user The address of the user whose claimable amount is to be calculated.
    /// @return The amount of tokens that can be claimed by the user.
    function getClaimable(address _user) external view returns (uint) {
        Vest memory _vest = vestMap[_user];

        uint _timeElapsed = block.timestamp - _vest.lastAccruedTime;

        if (_timeElapsed > _vest.remainingDuration) {
            return _vest.accrued + _vest.amount;
        }

        return _vest.accrued + (_vest.amount * _timeElapsed / _vest.remainingDuration);
    }

    /// @notice Calculates the current vesting state for a given user.
    /// @param _user The address of the user whose vesting state is to be calculated.
    /// @return The current vesting state of the specified user.
    function getVestingCursor(address _user) public view returns (Vest memory) {
        Vest memory _vest = vestMap[_user];

        uint _timeElapsed = block.timestamp - _vest.lastAccruedTime;

        if (_timeElapsed > _vest.remainingDuration) {
            return Vest({amount: 0, remainingDuration: 0, lastAccruedTime: block.timestamp, accrued: _vest.accrued + _vest.amount});
        }

        uint _accruedDelta = _timeElapsed * (_vest.amount / _vest.remainingDuration);

        return Vest({
            amount: _vest.amount - _accruedDelta,
            remainingDuration: _vest.remainingDuration - _timeElapsed,
            lastAccruedTime: block.timestamp,
            accrued: _vest.accrued + _accruedDelta
        });
    }

    /// @notice Locks tokens for a user, granting them voting power.
    /// @dev Emits a VotingEscrow__Lock event on successful lock.
    /// @param _depositor The address that provides the tokens to be locked.
    /// @param _user The address for whom the tokens are locked.
    /// @param _amount The amount of tokens to be locked.
    /// @param _duration The duration for which the tokens are to be locked.
    function lock(address _depositor, address _user, uint _amount, uint _duration) external auth {
        if (_amount == 0) revert VotingEscrow__ZeroAmount();
        if (_duration > MAXTIME) revert VotingEscrow__ExceedMaxTime();

        Lock memory _lock = lockMap[_user];

        router.transfer(token, _depositor, address(this), _amount);
        _mint(_user, _amount);

        uint _amountNext = _lock.amount + _amount;

        _lock.duration = (_lock.amount * _lock.duration + _amount * _duration) / _amountNext;
        _lock.amount = _amountNext;

        lockMap[_user] = _lock;

        emit VotingEscrow__Lock(_depositor, _user, _lock);
    }

    /// @notice Begins the vesting process for a user's locked tokens.
    /// @dev Emits a VotingEscrow__Vest event on successful vesting initiation.
    /// @param _user The address of the user whose tokens are to begin vesting.
    /// @param _receiver The address that will receive the vested tokens.
    /// @param _amount The amount of tokens to begin vesting.
    function vest(address _user, address _receiver, uint _amount) external auth {
        if (_amount == 0) revert VotingEscrow__ZeroAmount();

        Lock storage _lock = lockMap[_user];

        if (_amount > _lock.amount) {
            revert VotingEscrow__ExceedingLockAmount(_lock.amount);
        }

        _lock.amount -= _amount;

        Vest memory _vest = getVestingCursor(_user);

        _vest.remainingDuration = (_vest.amount * _vest.remainingDuration + _amount * _lock.duration) / (_vest.amount + _amount);
        _vest.amount = _vest.amount + _amount;

        vestMap[_user] = _vest;

        _burn(_user, _amount);

        emit VotingEscrow__Vest(_user, _receiver, _vest);
    }

    /// @notice Allows a user to claim their vested tokens.
    /// @dev Emits a VotingEscrow__Claim event on successful claim.
    /// @param _user The address of the user claiming their tokens.
    /// @param _receiver The address that will receive the claimed tokens.
    /// @param _amount The amount of tokens to be claimed.
    function claim(address _user, address _receiver, uint _amount) external auth {
        if (_amount == 0) revert VotingEscrow__ZeroAmount();
        Vest memory _vest = getVestingCursor(_user);

        if (_amount > _vest.accrued) {
            revert VotingEscrow__ExceedingAccruedAmount(_vest.accrued);
        }

        _vest.accrued -= _amount;
        vestMap[_user] = _vest;

        token.transfer(_receiver, _amount);

        emit VotingEscrow__Claim(_user, _receiver, _amount);
    }

    /// @notice Transfers are unsupported in this contract.
    function transfer(address, uint) public pure override returns (bool) {
        revert VotingEscrow__Unsupported();
    }

    /// @notice TransferFrom is unsupported in this contract.
    function transferFrom(address, address, uint) public pure override returns (bool) {
        revert VotingEscrow__Unsupported();
    }

    error VotingEscrow__ZeroAmount();
    error VotingEscrow__Unsupported();
    error VotingEscrow__ExceedMaxTime();
    error VotingEscrow__ExceedingAccruedAmount(uint accrued);
    error VotingEscrow__ExceedingLockAmount(uint amount);
}
