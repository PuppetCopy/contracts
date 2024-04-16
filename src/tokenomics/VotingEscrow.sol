// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {Router} from "../utils/Router.sol";

uint constant MAXTIME = 2 * 365 * 86400; // 2 years

// Voting escrow to have time-weighted votes
// Votes have a weight depending on time, so that users are committed
// to the future of (whatever they are voting for).
// The weight in this implementation is linear, and lock cannot be more than maxtime:
// w ^
// 1 +        /
//   |      /
//   |    /
//   |  /
//   |/
// 0 +--------+------> time
//       maxtime (2 years)
contract VotingEscrow is Auth {
    struct Point {
        uint bias;
        uint slope; // - dweight / dt
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

    string public constant name = "Puppet Voting Escrow";
    string public constant symbol = "vePUPPET";
    string public constant version = "0.0.1";

    uint public supply;
    uint public epoch;

    mapping(address => uint) public userPointEpoch;
    mapping(uint => uint) public slopeChanges; // time -> signed slope change
    mapping(address => LockedBalance) public locked;
    mapping(uint => Point) public pointHistory; // epoch -> unsigned point
    mapping(address => Point[1000000000]) public userPointHistory; // user -> Point[user_epoch]

    Router public immutable router;
    IERC20 public immutable token;

    // constants
    uint private constant WEEK = 1 weeks; // all future times are rounded by week
    uint private constant MULTIPLIER = 10 ** 18;
    address private constant ZERO_ADDRESS = address(0);

    // ============================================================================================
    // Constructor
    // ============================================================================================

    /// @notice Contract constructor
    /// @param _authority Aragon authority address
    /// @param _token `ERC20CRV` token address
    constructor(Authority _authority, Router _router, IERC20 _token) Auth(address(0), _authority) {
        router = _router;
        token = _token;

        pointHistory[0].blk = block.number;
        pointHistory[0].ts = _roundEpochTime(block.timestamp);
    }

    // view

    function getUserLastPoint(address _addr) external view returns (Point memory) {
        uint _uepoch = userPointEpoch[_addr];
        return userPointHistory[_addr][_uepoch];
    }

    function getUserPointHistory(address _addr, uint _idx) external view returns (Point memory) {
        return userPointHistory[_addr][_idx];
    }

    function getPointHistory(uint _idx) external view returns (Point memory) {
        return pointHistory[_idx];
    }

    function getLastUserSlope(address _addr) external view returns (uint) {
        uint _uepoch = userPointEpoch[_addr];
        return userPointHistory[_addr][_uepoch].slope;
    }

    function userPointHistoryTs(address _addr, uint _idx) external view returns (uint) {
        return userPointHistory[_addr][_idx].ts;
    }

    function lockedEnd(address _addr) external view returns (uint) {
        return locked[_addr].end;
    }

    function lockedAmount(address _addr) external view returns (uint) {
        return locked[_addr].amount;
    }

    function findTimestampUserEpoch(address _addr, uint _timestamp, uint _min, uint _max) public view returns (uint) {
        for (uint i = 0; i < 128; i++) {
            unchecked {
                if (_min >= _max) break;

                uint _mid = (_min + _max + 2) / 2;
                if (userPointHistory[_addr][_mid].ts <= _timestamp) {
                    _min = _mid;
                } else {
                    _max = _mid - 1;
                }
            }
        }
        return _min;
    }

    function findTimestampEpoch(uint timestamp) external view returns (uint) {
        uint _min = 0;
        uint _max = epoch;

        // Perform binary search through epochs to find epoch containing `timestamp`
        for (uint i = 0; i < 128; i++) {
            if (_min >= _max) break;

            // Algorithm assumes that inputs are less than 2^128 so this operation is safe.
            // +2 avoids getting stuck in min == mid < max
            uint mid = (_min + _max + 2) / 2;
            if (pointHistory[mid].ts <= timestamp) {
                _min = mid;
            } else {
                _max = mid - 1;
            }
        }
        return _min;
    }

    // NOTE: The following ERC20/minime-compatible methods are not real balanceOf and supply!
    // They measure the weights for the purpose of voting, so they don't represent real coins.

    function balanceOf(address _addr, uint _t) external view returns (uint) {
        return _balanceOf(_addr, _t);
    }

    function balanceOf(address _addr) external view returns (uint) {
        return _balanceOf(_addr, block.timestamp);
    }

    function balanceOfAt(address _addr, uint _block) external view returns (uint) {
        // Copying and pasting totalSupply code because Vyper cannot pass by
        // reference yet
        require(_block <= block.number);

        // Binary search
        uint _min = 0;
        uint _max = userPointEpoch[_addr];
        for (uint i = 0; i < 128; ++i) {
            // Will be always enough for 128-bit numbers
            if (_min >= _max) {
                break;
            }
            uint _mid = (_min + _max + 1) / 2;
            if (userPointHistory[_addr][_mid].blk <= _block) {
                _min = _mid;
            } else {
                _max = _mid - 1;
            }
        }

        Point memory upoint = userPointHistory[_addr][_min];

        uint _maxEpoch = epoch;
        uint _epoch = _findBlockEpoch(_block, _maxEpoch);
        Point memory _point0 = pointHistory[_epoch];
        uint _dBlock = 0;
        uint _dT = 0;
        if (_epoch < _maxEpoch) {
            Point memory _point1 = pointHistory[_epoch + 1];
            _dBlock = _point1.blk - _point0.blk;
            _dT = _point1.ts - _point0.ts;
        } else {
            _dBlock = block.number - _point0.blk;
            _dT = block.timestamp - _point0.ts;
        }
        uint _blockTime = _point0.ts;
        if (_dBlock != 0) {
            _blockTime += (_dT * (_block - _point0.blk)) / _dBlock;
        }

        upoint.bias -= upoint.slope * (_blockTime - upoint.ts);
        if (upoint.bias >= 0) {
            return upoint.bias;
        } else {
            return 0;
        }
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
        uint _targetEpoch = _findBlockEpoch(_block, _epoch);

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

    // state

    function checkpoint() external {
        _checkpoint(address(0), LockedBalance(0, 0), LockedBalance(0, 0));
    }

    function lock(address _from, address _to, uint _value, uint _unlockTime) external requiresAuth {
        LockedBalance storage _lock = locked[_to];
        LockedBalance memory _oldLock = _lock;

        if (_value == 0 && _unlockTime == 0 || _lock.amount == 0 && _value == 0) revert VotingEscrow__InvalidLockValue();

        _unlockTime = Math.max(_unlockTime, _lock.end);

        if (_unlockTime < (block.timestamp + WEEK)) revert VotingEscrow__InvaidLockingSchedule();

        _unlockTime = _roundEpochTime(Math.min(block.timestamp + MAXTIME, _unlockTime)); // Round down unlock time to the start of the week

        // Adding to existing lock, or if a lock is expired - creating a new one
        _lock.amount += _value;
        if (_unlockTime != 0) {
            _lock.end = _unlockTime;
        }

        supply += _value;

        _checkpoint(_to, _oldLock, _lock);

        if (_value > 0) router.transfer(token, _from, address(this), _value);

        emit VotingEscrow__Deposit(_from, _to, block.timestamp, _value, _unlockTime);
        emit VotingEscrow__Supply(block.timestamp, supply);
    }

    function withdraw(address _from, address _to) external requiresAuth {
        LockedBalance memory _storedLock = locked[_from];

        if (_storedLock.end > block.timestamp) revert VotingEscrow__LockNotExpired();
        if (_storedLock.amount == 0) revert VotingEscrow__NoLockFound();

        LockedBalance memory _newLock = LockedBalance(0, 0);

        locked[_from] = _newLock;
        supply -= _storedLock.amount;

        _checkpoint(_from, _storedLock, _newLock);
        token.transfer(_to, _storedLock.amount);

        emit VotingEscrow__Withdraw(_from, _to, block.timestamp, _storedLock.amount);
        emit VotingEscrow__Supply(block.timestamp, supply);
    }

    // internal

    /// @notice Binary search to estimate timestamp for block number
    /// @param _block Block to find
    /// @param _maxEpoch Don't go beyond this epoch
    /// @return Approximate timestamp for block
    function _findBlockEpoch(uint _block, uint _maxEpoch) internal view returns (uint) {
        // Binary search
        uint _min = 0;
        uint _max = _maxEpoch;
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

    function _totalSupply(uint _t) internal view returns (uint) {
        return _supplyAt(pointHistory[epoch], _t);
    }

    /// @notice Calculate total supply of voting power at a given time _t
    /// @param _point Most recent point before time _t
    /// @param _t Time at which to calculate supply
    /// @return totalSupply at given point in time
    function _supplyAt(Point memory _point, uint _t) internal view returns (uint) {
        Point memory _lastPoint = _point;
        uint _ti = _roundEpochTime(_lastPoint.ts);

        for (uint i; i < 255;) {
            _ti += WEEK;
            uint _dSlope = 0;
            if (_ti > _t) {
                _ti = _t;
            } else {
                _dSlope = slopeChanges[_ti];
            }
            _lastPoint.bias -= _lastPoint.slope * (_ti - _lastPoint.ts);
            if (_ti == _t) {
                break;
            }
            _lastPoint.slope += _dSlope;
            _lastPoint.ts = _ti;
            unchecked {
                ++i;
            }
        }

        return _lastPoint.bias;
    }

    /// @notice Get an address voting power
    /// @dev Adheres to the ERC20 `balanceOf` interface
    /// @param _addr User wallet address
    /// @param _t Epoch time to return voting power at
    /// @return User voting power
    function _balanceOf(address _addr, uint _t) internal view returns (uint) {
        uint _epoch = userPointEpoch[_addr];
        if (_epoch == 0) return 0;

        Point memory _lastPoint = userPointHistory[_addr][_epoch];
        _lastPoint.bias -= _lastPoint.slope * (_t - _lastPoint.ts);

        return _lastPoint.bias;
    }

    /// @notice Record global and per-user data to checkpoint
    /// @param _to User's wallet address. No user checkpoint if 0x0
    /// @param _oldLocked Pevious locked amount / end lock time for the user
    /// @param _newLocked New locked amount / end lock time for the user
    function _checkpoint(address _to, LockedBalance memory _oldLocked, LockedBalance memory _newLocked) internal {
        Point memory _uOld;
        Point memory _uNew;
        uint _oldDslope = 0;
        uint _newDslope = 0;
        uint _epoch = epoch;

        if (_to != ZERO_ADDRESS) {
            // Calculate slopes and biases
            // Kept at zero when they have to
            if (_oldLocked.end > block.timestamp && _oldLocked.amount > 0) {
                _uOld.slope = _oldLocked.amount / MAXTIME;
                _uOld.bias = _uOld.slope * (_oldLocked.end - block.timestamp);
            }
            if (_newLocked.end > block.timestamp && _newLocked.amount > 0) {
                _uNew.slope = _newLocked.amount / MAXTIME;
                _uNew.bias = _uNew.slope * (_newLocked.end - block.timestamp);
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
        }

        Point memory _lastPoint = Point({bias: 0, slope: 0, ts: block.timestamp, blk: block.number});
        if (_epoch > 0) {
            _lastPoint = pointHistory[_epoch];
        }
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
        uint _tI = (_lastCheckpoint / WEEK) * WEEK;
        for (uint i = 0; i < 255; ++i) {
            // Hopefully it won't happen that this won't get used in 5 years!
            // If it does, users will be able to withdraw but vote weight will be broken
            _tI += WEEK;
            uint _dSlope = 0;
            if (_tI > block.timestamp) {
                _tI = block.timestamp;
            } else {
                _dSlope = slopeChanges[_tI];
            }

            _lastPoint.bias -= _lastPoint.slope * (_tI - _lastCheckpoint);
            _lastPoint.slope += _dSlope;

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

        epoch = _epoch;
        // Now pointHistory is filled until t=now

        if (_to != ZERO_ADDRESS) {
            // If last point was in this block, the slope change has been applied already
            // But in such case we have 0 slope(s)
            _lastPoint.slope += (_uNew.slope - _uOld.slope);
            _lastPoint.bias += (_uNew.bias - _uOld.bias);
        }

        // Record the changed point into history
        pointHistory[_epoch] = _lastPoint;

        if (_to != ZERO_ADDRESS) {
            // Schedule the slope changes (slope is going down)
            // We subtract new_user_slope from [_newLocked.end]
            // and add old_user_slope to [_oldLocked.end]
            if (_oldLocked.end > block.timestamp) {
                // _oldDslope was <something> - _uOld.slope, so we cancel that
                _oldDslope += _uOld.slope;
                if (_newLocked.end == _oldLocked.end) {
                    // _oldDslope -= _uNew.slope; // It was a new deposit, not extension
                }
                slopeChanges[_oldLocked.end] = _oldDslope;
            }

            if (_newLocked.end > block.timestamp) {
                if (_newLocked.end > _oldLocked.end) {
                    // _newDslope -= _uNew.slope; // old slope disappeared at this point
                    slopeChanges[_newLocked.end] = _newDslope;
                }
                // else: we recorded it already in _oldDslope
            }
            // Now handle user history
            address addr = _to;
            uint _userEpoch = userPointEpoch[addr] + 1;

            userPointEpoch[addr] = _userEpoch;
            _uNew.ts = block.timestamp;
            _uNew.blk = block.number;
            userPointHistory[addr][_userEpoch] = _uNew;
        }
    }

    function _roundEpochTime(uint timestamp) private pure returns (uint) {
        unchecked {
            // Division by zero or overflows are impossible here.
            return (timestamp / WEEK) * WEEK;
        }
    }

    // ============================================================================================
    // Events
    // ============================================================================================

    event VotingEscrow__Deposit(address from, address to, uint timestamp, uint value, uint locktime);
    event VotingEscrow__Withdraw(address from, address to, uint timestamp, uint value);
    event VotingEscrow__Supply(uint timestamp, uint supply);

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
