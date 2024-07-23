// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

import {IAuthority} from "./../utils/interfaces/IAuthority.sol";
import {Auth} from "./../utils/access/Auth.sol";

import {Router} from "../shared/Router.sol";

uint constant MAXTIME = 2 * 365 * 86400; // 2 years

/**
 * @title Puppet Voting Escrow
 * @dev An ERC20 token with voting escrow capabilities.
 * The token is used to represent voting power in the governance system.
 * The token is minted by authiorized protocol contracts.
 * The token is non-transferable.
 */
contract VotingEscrow is Auth, ERC20Votes {
    event VotingEscrow__Lock(address depositor, address user, Lock lock);
    event VotingEscrow__Withdraw(address user, address receiver, Lock lock);
    event VotingEscrow__Release(address user, address receiver, Release release);

    struct Lock {
        uint amount;
        uint duration;
    }

    struct Release {
        uint amount;
        uint duration;
        uint lastSyncTime;
        uint accrued;
    }

    mapping(address => Lock) public lockMap;
    mapping(address => Release) public releaseMap;

    Router public immutable router;
    IERC20 public immutable token;

    constructor(IAuthority _authority, Router _router, IERC20 _token)
        Auth(_authority)
        ERC20("Puppet Voting Power", "vePUPPET")
        EIP712("Voting Escrow", "1")
    {
        router = _router;
        token = _token;
    }

    function getLock(address _user) external view returns (Lock memory) {
        return lockMap[_user];
    }

    function getRelease(address _user) external view returns (Release memory) {
        return releaseMap[_user];
    }

    function transfer(address, /*to*/ uint /*value*/ ) public pure override returns (bool) {
        revert VotingEscrow__Unsupported();
    }

    function transferFrom(address, /*from*/ address, /*to*/ uint /*value*/ ) public pure override returns (bool) {
        revert VotingEscrow__Unsupported();
    }

    // lock minted tokens on behalf of the user for a specified duration
    // the existing lock is updated with the new amount and duration weighted by the existing amount and duration
    function lock(
        address _depositor, //
        address _user,
        uint _amount,
        uint _duration
    ) external auth {
        if (_amount == 0 || _duration > MAXTIME) revert VotingEscrow__InvalidLock();

        Lock memory _lock = lockMap[_user];

        uint _lockedAmount = _lock.amount;
        uint _nextBalance = _lockedAmount + _amount;
        uint _nextDuration = (_lockedAmount * _lock.duration + _amount * _duration) / _nextBalance;

        lockMap[_user] = Lock({amount: _nextBalance, duration: _nextDuration});
        router.transfer(token, _depositor, address(this), _amount);
        _mint(_user, _amount);

        emit VotingEscrow__Lock(_depositor, _user, _lock);
    }

    // pool the user's locked tokens and release them to the receiver over time once release is called
    // the existing release schedule is updated with the new amount and duration weighted by the existing amount and duration
    function release(address _user, address _receiver, uint _amount) external auth {
        if (_amount == 0) revert VotingEscrow__ZeroAmount();

        Lock memory _lock = lockMap[_user];
        Release memory _release = releaseMap[_user];

        uint _nextBalance = _release.amount + _lock.amount;
        uint _nextDuration = (_lock.amount * _lock.duration + _amount * _release.duration) / _nextBalance;
        uint _emissionRate = _nextBalance / _nextDuration;

        releaseMap[_user] = Release({
            amount: _nextBalance,
            duration: _nextDuration,
            accrued: _release.accrued + ((block.timestamp - _release.lastSyncTime) * _emissionRate),
            lastSyncTime: block.timestamp
        });

        _burn(_user, _amount);

        emit VotingEscrow__Release(_user, _receiver, _release);
    }

    // withdraw the user's accrued tokens
    function withdraw(address _user, address _receiver, uint _amount) external auth {
        if (_amount == 0) revert VotingEscrow__ZeroAmount();
        Release memory _release = releaseMap[_user];

        uint _releaseRate = _release.amount / _release.duration;

        releaseMap[_user] = Release({
            amount: _release.amount, //
            duration: _release.duration,
            accrued: 0,
            lastSyncTime: block.timestamp
        });

        token.transfer(_receiver, _release.accrued + ((block.timestamp - _release.lastSyncTime) * _releaseRate));
    }

    function stake(address _depositor, address _user, uint _amount) external auth {
        router.transfer(token, _depositor, address(this), _amount);
        _mint(_user, _amount);
    }

    function unstake(address _user, uint _amount) external auth {
        token.transfer(_user, _amount);
        _burn(_user, _amount);
    }

    error VotingEscrow__ZeroAmount();
    error VotingEscrow__InvalidLock();
    error VotingEscrow__Unsupported();
}
