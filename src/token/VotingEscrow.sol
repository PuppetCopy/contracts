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

uint constant MAXTIME = 365 days * 2;

/**
 * @title Token Voting Escrow
 * @dev lock tokens for a certain period to obtain governance voting power.
 * The lock duration is subject to a weighted average adjustment when additional tokens are locked for a new duration. Upon unlocking, tokens enter a
 * vesting period, the duration of which is determined by the weighted average of the lock durations. The vesting period is recalculated whenever
 * additional tokens are locked, incorporating the new amount and duration into the weighted average.
 */
contract VotingEscrow is Permission, ERC20Votes {
    event VotingEscrow__Lock(address depositor, address user, Lock lock);
    event VotingEscrow__Vest(address user, address receiver, Vest vest);
    event VotingEscrow__Claim(address user, address receiver, uint amount);

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

    function getLock(address _user) external view returns (Lock memory) {
        return lockMap[_user];
    }

    function getVest(address _user) external view returns (Vest memory) {
        return vestMap[_user];
    }

    constructor(IAuthority _authority, Router _router, IERC20 _token)
        Permission(_authority)
        ERC20("Puppet Voting Power", "vePUPPET")
        EIP712("Voting Escrow", "1")
    {
        router = _router;
        token = _token;
    }

    function getClaimable(address _user) external view returns (uint) {
        Vest memory _vest = vestMap[_user];

        uint _timeElapsed = block.timestamp - _vest.lastAccruedTime;

        if (_timeElapsed > _vest.remainingDuration) {
            return _vest.accrued + _vest.amount;
        }

        return _vest.accrued + (_vest.amount * _timeElapsed / _vest.remainingDuration);
    }

    function getVestingCursor(address _user) public view returns (Vest memory) {
        Vest memory _vest = vestMap[_user];

        uint _timeElapsed = block.timestamp - _vest.lastAccruedTime;

        if (_timeElapsed > _vest.remainingDuration) {
            return Vest({
                amount: 0, //
                remainingDuration: 0,
                lastAccruedTime: block.timestamp,
                accrued: _vest.accrued + _vest.amount
            });
        }

        uint _accuredDelta = _timeElapsed * (_vest.amount / _vest.remainingDuration);

        return Vest({
            amount: _vest.amount - _accuredDelta,
            remainingDuration: _vest.remainingDuration - _timeElapsed,
            lastAccruedTime: block.timestamp,
            accrued: _vest.accrued + _accuredDelta
        });
    }

    // mutate

    function transfer(address, /*to*/ uint /*value*/ ) public pure override returns (bool) {
        revert VotingEscrow__Unsupported();
    }

    function transferFrom(address, /*from*/ address, /*to*/ uint /*value*/ ) public pure override returns (bool) {
        revert VotingEscrow__Unsupported();
    }

    function lock(
        address _depositor, //
        address _user,
        uint _amount,
        uint _duration
    ) external auth {
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

    function vest(address _user, address _receiver, uint _amount) external auth {
        if (_amount == 0) revert VotingEscrow__ZeroAmount();

        Lock storage _lock = lockMap[_user];

        if (_amount > _lock.amount) {
            revert VotingEscrow__ExceedingLockAmount(_lock.amount);
        }

        _lock.amount -= _amount;

        Vest memory _vest = getVestingCursor(_user);

        // average next remaining duration
        _vest.remainingDuration = (_vest.amount * _vest.remainingDuration + _amount * _lock.duration) / (_vest.amount + _amount);
        _vest.amount = _vest.amount + _amount;

        vestMap[_user] = _vest;

        // vested tokens are excluded from governance voting rights
        _burn(_user, _amount);

        emit VotingEscrow__Vest(_user, _receiver, _vest);
    }

    // claim the user's released tokens
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

    error VotingEscrow__ZeroAmount();
    error VotingEscrow__Unsupported();
    error VotingEscrow__ExceedMaxTime();
    error VotingEscrow__ExceedingAccruedAmount(uint accrued);
    error VotingEscrow__ExceedingLockAmount(uint amount);
}
