// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

import {IAuthority} from "./../utils/interfaces/IAuthority.sol";
import {Auth} from "./../utils/auth/Auth.sol";

import {Router} from "../shared/Router.sol";

uint constant MAXTIME = 2 * 365 * 86400; // 2 years

/**
 * @title Voting Escrow
 * @notice modified version of Curve's VotingEscrow
 *
 * Voting escrow to have time-weighted votes
 * Votes have a weight depending on time, so that users are committed
 * to the future of (whatever they are voting for).
 * The weight in this implementation is linear, and lock cannot be more than maxtime:
 * w ^
 * 1 +        /
 *   |      /
 *   |    /
 *   |  /
 *   |/
 * 0 +--------+------> time
 *       maxtime (2 years)
 */
contract VotingEscrow is Auth, EIP712 {
    struct Point {
        int bias;
        int slope; // - dweight / dt
        uint ts;
        uint blk; // block
    }
    // We cannot really do block numbers per se b/c slope is per time, not per block
    // and per block could be fairly bad b/c Ethereum changes blocktimes.
    // What we can do is to extrapolate ***At functions

    struct LockedBalance {
        uint amount;
        uint end;
    }

    uint public supply;
    uint public epoch;

    mapping(address => uint) public userPointEpoch;
    mapping(uint => int) public slopeChanges; // time -> signed slope change
    mapping(address => LockedBalance) public locked;
    mapping(uint => Point) public pointHistory; // epoch -> unsigned point
    mapping(address => Point[1000000000]) public userPointHistory; // user -> Point[user_epoch]

    Router public immutable router;
    IERC20 public immutable token;

    // constants
    uint private constant WEEK = 1 weeks; // all future times are rounded by week
    uint private constant MULTIPLIER = 10 ** 18;

    // ============================================================================================
    // Constructor
    // ============================================================================================

    /// @notice Contract constructor
    /// @param _authority Aragon authority address
    /// @param _token `ERC20CRV` token address
    constructor(IAuthority _authority, Router _router, IERC20 _token) Auth(_authority) EIP712("Puppet Voting Escrow", "1") {
        router = _router;
        token = _token;

        pointHistory[0] = Point({
            bias: 0, //
            slope: 0,
            ts: block.timestamp,
            blk: block.number
        });
    }

    // view

    function getPoints(address _user) external view returns (Point memory, Point memory) {
        return (pointHistory[epoch], userPointHistory[_user][userPointEpoch[_user]]);
    }

    function getUserPoint(address _user) external view returns (Point memory) {
        return userPointHistory[_user][userPointEpoch[_user]];
    }

    function getUserPoint(address _user, uint _idx) external view returns (Point memory) {
        return userPointHistory[_user][_idx];
    }

    function getPoint(uint _idx) external view returns (Point memory) {
        return pointHistory[_idx];
    }

    function getPoint() external view returns (Point memory) {
        return pointHistory[epoch];
    }

    function getLock(address _user) external view returns (LockedBalance memory) {
        return locked[_user];
    }

    function findTimestampUserEpoch(address _user, uint _timestamp, uint _min, uint _max) public view returns (uint) {
        for (uint i = 0; i < 128; i++) {
            unchecked {
                if (_min >= _max) break;

                uint _mid = (_min + _max + 2) / 2;
                if (userPointHistory[_user][_mid].ts <= _timestamp) {
                    _min = _mid;
                } else {
                    _max = _mid - 1;
                }
            }
        }
        return _min;
    }

    function findTimestampEpoch(uint _timestamp) external view returns (uint) {
        uint _min = 0;
        uint _max = epoch;

        // Perform binary search through epochs to find epoch containing `timestamp`
        for (uint i = 0; i < 128; i++) {
            if (_min >= _max) break;

            // Algorithm assumes that inputs are less than 2^128 so this operation is safe.
            // +2 avoids getting stuck in min == mid < max
            uint mid = (_min + _max + 2) / 2;
            if (pointHistory[mid].ts <= _timestamp) {
                _min = mid;
            } else {
                _max = mid - 1;
            }
        }
        return _min;
    }

    function balanceOf(address _user) public view returns (uint) {
        return _balanceOf(_user, block.timestamp);
    }

    function balanceOf(address _user, uint _t) public view returns (uint) {
        return _balanceOf(_user, _t);
    }

    function totalSupply() external view returns (uint) {
        return _totalSupply(block.timestamp);
    }

    function totalSupply(uint _t) external view returns (uint) {
        return _totalSupply(_t);
    }

    function totalSupplyAt(uint _block) external view returns (uint) {
        require(_block <= block.number);

        uint _epoch = epoch;
        uint _targetEpoch = _findBlockEpoch(_block, 0, _epoch);

        Point memory _point = pointHistory[_targetEpoch];
        uint _dt = 0;
        if (_targetEpoch < _epoch) {
            Point memory _pointNext = pointHistory[_targetEpoch + 1];
            if (_point.blk != _pointNext.blk) {
                _dt = ((_block - _point.blk) * (_pointNext.ts - _point.ts)) / (_pointNext.blk - _point.blk);
            }
        } else {
            if (_point.blk != block.number) {
                _dt = ((_block - _point.blk) * (block.timestamp - _point.ts)) / (block.number - _point.blk);
            }
        }

        // Now dt contains info on how far are we beyond point
        return _supplyAt(_point, _point.ts + _dt);
    }

    // integration

    function lockFor(
        address _depositor, //
        address _user,
        uint _value,
        uint _unlockTime
    ) external auth returns (Point memory _lastPoint, Point memory _uNew) {
        LockedBalance memory _newLock = locked[_user];

        if (_value == 0 && _unlockTime == 0 || _newLock.amount == 0 && _value == 0) revert VotingEscrow__InvalidLockValue();

        _unlockTime = Math.max(_unlockTime, _newLock.end);

        if (_unlockTime < (block.timestamp + WEEK)) revert VotingEscrow__InvaidLockingSchedule();

        _unlockTime = _roundWeekTime(Math.min(block.timestamp + MAXTIME, _unlockTime)); // Round down unlock time to the start of the week

        LockedBalance memory _oldLock = LockedBalance({amount: _newLock.amount, end: _newLock.end});

        // Adding to existing lock, or if a lock is expired - creating a new one
        _newLock.amount += _value;
        if (_unlockTime != 0) {
            _newLock.end = _unlockTime;
        }

        locked[_user] = _newLock;
        uint _supply = supply + _value;
        supply = _supply;
        (_lastPoint, _uNew) = _checkpoint(_user, _oldLock, _newLock);

        if (_value > 0) router.transfer(token, _depositor, address(this), _value);

        emit VotingEscrow__Deposit(_depositor, _user, block.timestamp, _value, _unlockTime);
        emit VotingEscrow__Point(block.timestamp, _supply, _lastPoint);
    }

    function withdrawFor(address _user, address _receiver) external auth {
        LockedBalance memory _oldLock = locked[_user];

        if (_oldLock.end > block.timestamp) revert VotingEscrow__LockNotExpired();
        if (_oldLock.amount == 0) revert VotingEscrow__NoLockFound();

        LockedBalance memory _newLock = LockedBalance(0, 0);

        uint _value = _oldLock.amount;

        locked[_user] = _newLock;

        uint _supply = supply - _value;
        supply = _supply;

        _checkpoint(_user, _oldLock, _newLock);
        token.transfer(_receiver, _value);

        emit VotingEscrow__Withdraw(_user, _receiver, block.timestamp, _value);
    }

    // internal

    /// @notice Record global and per-user data to checkpoint
    /// @param _user User's wallet address. No user checkpoint if 0x0
    /// @param _oldLocked Pevious locked amount / end lock time for the user
    /// @param _newLocked New locked amount / end lock time for the user
    function _checkpoint(address _user, LockedBalance memory _oldLocked, LockedBalance memory _newLocked)
        internal
        returns (Point memory _lastPoint, Point memory _uNew)
    {
        Point memory _uOld;
        int _oldDslope = 0;
        int _newDslope = 0;
        uint _epoch = epoch;

        // Calculate slopes and biases
        // Kept at zero when they have to
        if (_oldLocked.end > block.timestamp && _oldLocked.amount > 0) {
            _uOld.slope = int(_oldLocked.amount / MAXTIME);
            _uOld.bias = _uOld.slope * int(_oldLocked.end - block.timestamp);
        }
        if (_newLocked.end > block.timestamp && _newLocked.amount > 0) {
            _uNew.slope = int(_newLocked.amount / MAXTIME);
            _uNew.bias = _uNew.slope * int(_newLocked.end - block.timestamp);
        }

        // Read values of scheduled changes in the slope
        // _oldLocked.end can be in the past and in the future
        // _newLocked.end can ONLY by in the FUTURE unless everything expired: than zeros
        _oldDslope = slopeChanges[_oldLocked.end];
        if (_newLocked.end != 0) {
            if (_newLocked.end == _oldLocked.end) {
                _newDslope = _oldDslope;
            } else {
                _newDslope = slopeChanges[_newLocked.end];
            }
        }

        _lastPoint = pointHistory[_epoch];

        uint _lastCheckpoint = _lastPoint.ts;
        // initial_last_point is used for extrapolation to calculate block number
        // (approximately, for *At methods) and save them
        // as we cannot figure that out exactly from inside the contract
        uint _initialLastPointTs = _lastPoint.ts;
        uint _initialLastPointBlk = _lastPoint.blk;

        uint _blockSlope = 0; // dblock/dt
        if (block.timestamp > _lastPoint.ts) {
            _blockSlope = (MULTIPLIER * (block.number - _lastPoint.blk)) / (block.timestamp - _lastPoint.ts);
        }
        // If last point is already recorded in this block, slope=0
        // But that's ok b/c we know the block in such case

        // Go over weeks to fill history and calculate what the current point is
        {
            uint _tI = _roundWeekTime(_lastCheckpoint);
            for (uint i = 0; i < 255; ++i) {
                // Hopefully it won't happen that this won't get used in 5 years!
                // If it does, users will be able to withdraw but vote weight will be broken
                _tI += WEEK;
                int _dSlope = 0;
                if (_tI > block.timestamp) {
                    _tI = block.timestamp;
                } else {
                    _dSlope = slopeChanges[_tI];
                }

                _lastPoint.bias -= _lastPoint.slope * int(_tI - _lastCheckpoint);
                _lastPoint.slope += _dSlope;

                if (_lastPoint.bias < 0) {
                    // This can happen
                    _lastPoint.bias = 0;
                }
                if (_lastPoint.slope < 0) {
                    // This cannot happen - just in case
                    _lastPoint.slope = 0;
                }
                _lastCheckpoint = _tI;
                _lastPoint.ts = _tI;
                _lastPoint.blk = _initialLastPointBlk + (_blockSlope * (_tI - _initialLastPointTs)) / MULTIPLIER;
                _epoch += 1;
                if (_tI == block.timestamp) {
                    _lastPoint.blk = block.number;
                    break;
                } else {
                    pointHistory[_epoch] = _lastPoint;
                }
            }
        }

        epoch = _epoch;
        // Now pointHistory is filled until t=now

        // If last point was in this block, the slope change has been applied already
        // But in such case we have 0 slope(s)
        _lastPoint.slope += (_uNew.slope - _uOld.slope);
        _lastPoint.bias += (_uNew.bias - _uOld.bias);
        if (_lastPoint.slope < 0) {
            _lastPoint.slope = 0;
        }
        if (_lastPoint.bias < 0) {
            _lastPoint.bias = 0;
        }

        // Record the changed point into history
        pointHistory[_epoch] = _lastPoint;

        // Schedule the slope changes (slope is going down)
        // We subtract new_user_slope from [_newLocked.end]
        // and add old_user_slope to [_oldLocked.end]
        if (_oldLocked.end > block.timestamp) {
            // _oldDslope was <something> - _uOld.slope, so we cancel that
            _oldDslope += _uOld.slope;
            if (_newLocked.end == _oldLocked.end) {
                _oldDslope -= _uNew.slope; // It was a new deposit, not extension
            }
            slopeChanges[_oldLocked.end] = _oldDslope;
        }

        if (_newLocked.end > block.timestamp) {
            if (_newLocked.end > _oldLocked.end) {
                _newDslope -= _uNew.slope; // old slope disappeared at this point
                slopeChanges[_newLocked.end] = _newDslope;
            }
            // else: we recorded it already in _oldDslope
        }
        // Now handle user history
        address _userAddr = _user;
        uint _userEpoch = userPointEpoch[_userAddr] + 1;

        userPointEpoch[_userAddr] = _userEpoch;
        _uNew.ts = block.timestamp;
        _uNew.blk = block.number;
        userPointHistory[_userAddr][_userEpoch] = _uNew;
    }

    /// @notice Binary search to estimate timestamp for block number
    /// @param _block Block to find
    /// @param _min Minimum epoch to search
    /// @param _max Maximum epoch to search
    /// @return Approximate timestamp for block
    function _findBlockEpoch(uint _block, uint _min, uint _max) internal view returns (uint) {
        // Binary search
        for (uint i = 0; i < 128; i++) {
            // Will always be enough for 128-bit numbers
            if (_min >= _max) {
                break;
            }
            uint _mid = (_min + _max + 1) / 2;
            if (pointHistory[_mid].blk <= _block) {
                _min = _mid;
            } else {
                _max = _mid - 1;
            }
        }
        return _min;
    }

    function _totalSupply(uint _time) internal view returns (uint) {
        return _supplyAt(pointHistory[epoch], _time);
    }

    /// @notice Calculate total supply of voting power at a given time _t
    /// @param _point Most recent point before time _t
    /// @param _time Time at which to calculate supply
    /// @return totalSupply at given point in time
    function _supplyAt(Point memory _point, uint _time) internal view returns (uint) {
        Point memory _lastPoint = _point;
        uint _ti = _roundWeekTime(_lastPoint.ts);

        for (uint i; i < 255;) {
            _ti += WEEK;
            int _dSlope = 0;
            if (_ti > _time) {
                _ti = _time;
            } else {
                _dSlope = slopeChanges[_ti];
            }
            _lastPoint.bias -= _lastPoint.slope * (int(_ti) - int(_lastPoint.ts));
            if (_ti == _time) {
                break;
            }
            _lastPoint.slope += _dSlope;
            _lastPoint.ts = _ti;
            unchecked {
                ++i;
            }
        }

        if (_lastPoint.bias < 0) {
            _lastPoint.bias = 0;
        }
        return _nonNegative(_lastPoint.bias);
    }

    /// @notice Get an address voting power
    /// @dev Adheres to the ERC20 `balanceOf` interface
    /// @param _user User wallet address
    /// @param _time Epoch time to return voting power at
    /// @return User voting power
    function _balanceOf(address _user, uint _time) internal view returns (uint) {
        uint _epoch = userPointEpoch[_user];
        if (_epoch == 0) return 0;

        Point memory _lastPoint = userPointHistory[_user][_epoch];
        int _dt = int(_time) - int(_lastPoint.ts);
        int _bias = _lastPoint.bias - _lastPoint.slope * _dt;

        return _nonNegative(_bias);
    }

    function _roundWeekTime(uint timestamp) private pure returns (uint) {
        unchecked {
            // Division by zero or overflows are impossible here.
            return (timestamp / WEEK) * WEEK;
        }
    }

    function _nonNegative(int n) internal pure returns (uint) {
        return n > 0 ? uint(n) : 0;
    }

    // ============================================================================================
    // Events
    // ============================================================================================

    event VotingEscrow__Deposit(address depositor, address user, uint timestamp, uint value, uint locktime);
    event VotingEscrow__Withdraw(address user, address receiver, uint timestamp, uint value);
    event VotingEscrow__Point(uint timestamp, uint supply, Point _point);

    // ============================================================================================
    // Errors
    // ============================================================================================

    error VotingEscrow__ZeroAddress();
    error VotingEscrow__LockNotExpired();
    error VotingEscrow__NoLockFound();
    error VotingEscrow__InvaidLockingSchedule();
    error VotingEscrow__LockExpired();
    error VotingEscrow__InvalidLockValue();
}
