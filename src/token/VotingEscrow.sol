// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

import {IERC20Mintable} from "src/utils/interfaces/IERC20Mintable.sol";
import {IAuthority} from "src/utils/interfaces/IAuthority.sol";
import {Permission} from "src/utils/access/Permission.sol";
import {Precision} from "src/utils/Precision.sol";

import {Router} from "src/shared/Router.sol";

uint constant MAXTIME = 365 days * 2; // 1 year

/**
 * @title Token Voting Escrow
 * @dev A token that allows users to lock their tokens for a specified duration and receive a bonus
 */
contract VotingEscrow is Permission, ERC20Votes {
    event VotingEscrow__Lock(address depositor, address user, uint duration, uint bonus, Lock lock);
    event VotingEscrow__Vest(address user, address receiver, Vest vest);
    event VotingEscrow__Claim(address user, address receiver, Vest vest, uint amount);

    struct Lock {
        uint amount;
        uint duration;
    }

    struct Vest {
        uint amount;
        uint duration;
        uint lastSyncTime;
        uint accrued;
    }

    mapping(address => Lock) public lockMap;
    mapping(address => Vest) public vestMap;

    Router public immutable router;
    IERC20Mintable public immutable token;

    uint public bonusMultiplier = 1e30;

    constructor(IAuthority _authority, Router _router, IERC20Mintable _token)
        Permission(_authority)
        ERC20("Puppet Voting Power", "vePUPPET")
        EIP712("Voting Escrow", "1")
    {
        router = _router;
        token = _token;
    }

    function getLock(address _user) external view returns (Lock memory) {
        return lockMap[_user];
    }

    function getRelease(address _user) external view returns (Vest memory) {
        return vestMap[_user];
    }

    function transfer(address, /*to*/ uint /*value*/ ) public pure override returns (bool) {
        revert VotingEscrow__Unsupported();
    }

    function transferFrom(address, /*from*/ address, /*to*/ uint /*value*/ ) public pure override returns (bool) {
        revert VotingEscrow__Unsupported();
    }

    // lock deposited tokens on behalf of the user for a specified duration
    // receive both governance tokens and bonus tokens based on the lock duration
    // the existing lock is updated with the new amount and duration weighted by the existing amount and duration
    function lock(
        address _depositor, //
        address _user,
        uint _amount,
        uint _duration
    ) external auth {
        if (_amount == 0) revert VotingEscrow__ZeroAmount();

        Lock memory _lock = lockMap[_user];

        router.transfer(token, _depositor, address(this), _amount);
        _mint(_user, _amount);

        uint _bonusToken = Precision.applyFactor(_amount, getLockRewardMultiplier(bonusMultiplier, _duration));
        uint _totalAdded = _amount + _bonusToken;
        token.mint(address(this), _bonusToken);

        _lock.amount = _lock.amount + _totalAdded;
        _lock.duration = (_lock.amount * _lock.duration + _totalAdded * _duration) / _lock.amount;
        lockMap[_user] = _lock;

        emit VotingEscrow__Lock(_depositor, _user, _duration, _bonusToken, _lock);
    }

    // pool the user's locked tokens and vest them to the receiver over time once release is called
    // the existing vesting schedule is averaged weighted whenever new amount and duration is added
    function vest(address _user, address _receiver, uint _amount) external auth {
        if (_amount == 0) revert VotingEscrow__ZeroAmount();

        // vested tokens are excluded from governance voting power
        _burn(_user, _amount);

        Lock memory _lock = lockMap[_user];

        lockMap[_user] = Lock({amount: _lock.amount - _amount, duration: _lock.duration});

        Vest memory _vest = getVestingCursor(_user);

        _vest.amount = _vest.amount + _lock.amount;
        _vest.duration = (_lock.amount * _lock.duration + _amount * _vest.duration) / _vest.amount;
        vestMap[_user] = _vest;

        emit VotingEscrow__Vest(_user, _receiver, _vest);
    }

    // claim the user's released tokens
    function claim(address _user, address _receiver, uint _amount) external auth {
        if (_amount == 0) revert VotingEscrow__ZeroAmount();
        Vest memory _vest = getVestingCursor(_user);

        _vest.accrued = _vest.accrued - _amount;
        vestMap[_user] = _vest;

        router.transfer(token, address(this), _receiver, _amount);

        emit VotingEscrow__Claim(_user, _receiver, _vest, _amount);
    }

    function claimable(address _user) external view returns (uint) {
        Vest memory _vest = vestMap[_user];
        uint _timeElapsed = block.timestamp - _vest.lastSyncTime;
        uint _emissionRate = _vest.amount / _vest.duration;

        return _vest.accrued + Math.min(_vest.amount, (_timeElapsed * _emissionRate));
    }

    function getVestingCursor(address _user) internal view returns (Vest memory _vest) {
        _vest = vestMap[_user];
        uint _timeElapsed = block.timestamp - _vest.lastSyncTime;
        uint _nextAccured = _vest.accrued + Math.min(_vest.amount, (_timeElapsed * (_vest.amount / _vest.duration)));

        _vest.duration = _timeElapsed > _vest.duration ? 0 : _vest.duration - _timeElapsed;
        _vest.accrued = _vest.accrued + _nextAccured;
        _vest.amount = _vest.amount - _nextAccured;
        _vest.lastSyncTime = block.timestamp;
    }

    function getLockRewardMultiplier(uint _bonusMultiplier, uint _lockDuration) public pure returns (uint) {
        return Precision.applyFactor(_bonusMultiplier, Precision.toFactor(_lockDuration, MAXTIME));
    }

    function configBonusMultiplier(uint _bonusMultiplier) external auth {
        bonusMultiplier = _bonusMultiplier;
    }

    error VotingEscrow__ZeroAmount();
    error VotingEscrow__Unsupported();
}
