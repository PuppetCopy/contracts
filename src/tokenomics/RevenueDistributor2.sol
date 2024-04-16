// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";

import {Precision} from "./../utils/Precision.sol";
import {VotingEscrow} from "./VotingEscrow.sol";
import {Router} from "../utils/Router.sol";

contract RevenueDistributor2 is ReentrancyGuard, EIP712, Auth {
    event CheckpointToken(uint time, uint tokens);
    event Claimed(address addr, uint amount, uint claim_epoch, uint maxEpoch);

    uint constant WEEK = 7 * 86400;

    uint public startTime;
    uint public timeCursor;

    mapping(address => uint) public userTimeCursorMap;
    mapping(address => uint) public userEpochMap;
    mapping(IERC20 => mapping(uint => uint)) tokensPerWeekMap;
    mapping(IERC20 => uint) tokensBalanceMap;
    mapping(IERC20 => uint) lastTokenTimeMap;

    VotingEscrow public votingEscrow;
    Router immutable router;

    uint[1000000000000000] public veSupply;

    constructor(Authority _authority, VotingEscrow _votingEscrow, Router _router, uint _startTime)
        EIP712("FeeDistributor", "1")
        Auth(address(0), _authority)
    {
        votingEscrow = _votingEscrow;
        router = _router;

        uint _t = _roundTimestamp(_startTime);
        startTime = _t;
        timeCursor = _t;

        votingEscrow = _votingEscrow;
    }

    function checkpointToken(IERC20 _token) external {
        uint _balance = _token.balanceOf(address(this));
        uint _amountIn = _balance - tokensBalanceMap[_token];

        tokensBalanceMap[_token] = _balance;
        lastTokenTimeMap[_token] = block.timestamp;

        uint _currentWeek = _roundTimestamp(block.timestamp);
        uint _nextWeek = _roundTimestamp(block.timestamp + WEEK);
        uint _offset = _nextWeek - _currentWeek;
        uint _trailNextWeek = Precision.applyFactor(Precision.toFactor(_offset, WEEK), _amountIn);

        tokensPerWeekMap[_token][_nextWeek] += _trailNextWeek;
        tokensPerWeekMap[_token][_currentWeek] += _amountIn - _trailNextWeek;

        emit CheckpointToken(block.timestamp, _amountIn);
    }

    // function checkpointTokenLegacy(IERC20 _token) external {
    //     uint _balance = _token.balanceOf(address(this));
    //     uint _tokenBalanceDelta = _balance - tokensBalanceMap[_token];

    //     tokensBalanceMap[_token] = _balance;
    //     lastTokenTimeMap[_token] = block.timestamp;

    //     uint _tt = Math.max(lastTokenTimeMap[_token], startTime);
    //     uint _sinceLast = block.timestamp - _tt;

    //     uint _thisWeekCursor = _roundTimestamp(_tt);
    //     uint _nextWeek = 0;

    //     for (uint i = 0; i < 20; i++) {
    //         _nextWeek = _thisWeekCursor + WEEK;
    //         if (_nextWeek > block.timestamp) {
    //             tokensPerWeekMap[_token][_thisWeekCursor] += _sinceLast > 0 && block.timestamp != _tt
    //                 ? (_tokenBalanceDelta * (block.timestamp - _tt)) / _sinceLast //
    //                 : _tokenBalanceDelta;

    //             break;
    //         } else {
    //             tokensPerWeekMap[_token][_thisWeekCursor] += _sinceLast > 0 && _nextWeek != _tt
    //                 ? (_tokenBalanceDelta * (_nextWeek - _tt)) / _sinceLast //
    //                 : _tokenBalanceDelta;
    //         }
    //         _tt = _nextWeek;
    //         _thisWeekCursor = _nextWeek;
    //     }
    //     emit CheckpointToken(block.timestamp, _tokenBalanceDelta);
    // }

    function checkpointTotalSupply() external {
        _checkpointTotalSupply();
    }

    function _calculateDistribution(
        IERC20 _token, //
        address _user,
        uint _weekCursor,
        uint _lastTokenTime,
        uint _lastUserEpoch
    ) internal view returns (uint _userEpoch, uint _toDistribute) {
        _userEpoch = 0;
        _toDistribute = 0;

        uint _startTime = startTime;

        if (_weekCursor == 0) {
            _userEpoch = votingEscrow.findTimestampUserEpoch(_user, _startTime, 0, _lastUserEpoch);
        } else {
            _userEpoch = userEpochMap[_user];
        }

        if (_userEpoch == 0) _userEpoch = 1;

        VotingEscrow.Point memory _userPoint = votingEscrow.getUserPointHistory(_user, _userEpoch);

        if (_weekCursor == 0) _weekCursor = _roundTimestamp(_userPoint.ts + WEEK - 1);
        if (_weekCursor < _startTime) _weekCursor = _startTime;

        VotingEscrow.Point memory _oldUserPoint;

        for (uint i = 0; i < 50; i++) {
            if (_weekCursor >= _lastTokenTime) break;

            if (_weekCursor >= _userPoint.ts && _userEpoch <= _lastUserEpoch) {
                _userEpoch += 1;
                _oldUserPoint = _userPoint;
                if (_userEpoch > _lastUserEpoch) {
                    _userPoint = VotingEscrow.Point(0, 0, 0, 0);
                } else {
                    _userPoint = votingEscrow.getUserPointHistory(_user, _userEpoch);
                }
            } else {
                uint balanceOf = getBalance(_oldUserPoint, _weekCursor);
                if (balanceOf == 0 && _userEpoch > _lastUserEpoch) break;
                if (balanceOf > 0) {
                    _toDistribute += (balanceOf * tokensPerWeekMap[_token][_weekCursor]) / veSupply[_weekCursor];
                }
                _weekCursor += WEEK;
            }
        }

        _userEpoch = Math.min(_lastUserEpoch, _userEpoch - 1);
    }

    function getClaimable(IERC20 _token, address _account) public view returns (uint) {
        uint _weekCursor = userTimeCursorMap[msg.sender];
        uint lastTokenTime = lastTokenTimeMap[_token];

        if (_weekCursor >= lastTokenTime) return 0;

        uint _lastUserEpoch = votingEscrow.userPointEpoch(msg.sender);
        if (_lastUserEpoch == 0) return 0;

        uint _lastTokenTime = _roundTimestamp(lastTokenTime);

        (, uint _toDistribute) = _calculateDistribution(_token, _account, _weekCursor, _lastTokenTime, _lastUserEpoch);

        return _toDistribute;
    }

    function claim(IERC20 _token, address _receiver) public {
        _checkpointTotalSupply();

        uint lastTokenTime = lastTokenTimeMap[_token];
        uint _weekCursor = userTimeCursorMap[msg.sender];
        if (_weekCursor >= lastTokenTime) revert RevenueDistributor__NoClaimableAmount();

        uint _lastUserEpoch = votingEscrow.userPointEpoch(msg.sender);
        if (_lastUserEpoch == 0) revert RevenueDistributor__NoClaimableAmount();

        uint _lastTokenTime = lastTokenTime;
        _lastTokenTime = _roundTimestamp(_lastTokenTime);

        (uint _userEpoch, uint _toDistribute) = _calculateDistribution(_token, msg.sender, _weekCursor, _lastTokenTime, _lastUserEpoch);

        userEpochMap[msg.sender] = _userEpoch;
        userTimeCursorMap[msg.sender] = _weekCursor;
        emit Claimed(msg.sender, _toDistribute, _userEpoch, _lastUserEpoch);

        if (_toDistribute > 0) {
            tokensBalanceMap[_token] -= _toDistribute;
            _token.transfer(_receiver, _toDistribute);
        }
    }

    // Internal

    function _checkpointTotalSupply() internal {
        uint _ti = timeCursor;
        uint _weekTime = _roundTimestamp(block.timestamp);
        for (uint i = 0; i < 20; i++) {
            if (_ti > _weekTime || block.timestamp == _weekTime) {
                break;
            } else {
                uint epoch = votingEscrow.findTimestampEpoch(_ti);
                VotingEscrow.Point memory pt = votingEscrow.getPointHistory(epoch);
                int128 dt = 0;
                if (_ti > pt.ts) {
                    dt = int128(int(_ti - pt.ts));
                }
                veSupply[_ti] = getBalance(pt, _ti);
            }
            _ti += WEEK;
        }
        timeCursor = _ti;
    }

    function getBalance(VotingEscrow.Point memory _point, uint _ti) internal pure returns (uint) {
        int128 dt = int128(int(_ti - _point.ts));

        return Math.max(uint(int(_point.bias - dt * _point.slope)), 0);
    }

    function _roundTimestamp(uint _timestamp) private pure returns (uint) {
        // Division by zero or overflows are impossible here.
        return (_timestamp / WEEK) * WEEK;
    }

    error RevenueDistributor__NoClaimableAmount();
}
