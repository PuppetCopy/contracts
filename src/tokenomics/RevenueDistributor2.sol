// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

import {Precision} from "./../utils/Precision.sol";
import {VotingEscrow} from "./VotingEscrow.sol";
import {Router} from "../utils/Router.sol";

contract RevenueDistributor2 is ReentrancyGuard, EIP712, Auth {
    event RevenueDistributor2__CheckpointToken(uint time, uint tokens);
    event RevenueDistributor2__Claimed(address addr, uint claimCursor, uint amount);

    uint constant WEEK = 7 * 86400;

    uint public startTime;
    uint public timeCursor;

    mapping(IERC20 => mapping(uint => uint)) tokensPerWeekMap;
    mapping(IERC20 => uint) tokensBalanceMap;

    mapping(IERC20 => mapping(address => uint)) public userClaimCursorMap;
    mapping(IERC20 => uint) tokenCursorMap;

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

    function checkpoint(IERC20 _token) external {
        uint _weekTime = _roundTimestamp(block.timestamp);

        _checkpointToken(_token, _weekTime);
        _checkpointSupply(_weekTime);
    }

    function checkpointSupply() external {
        uint _weekTime = _roundTimestamp(block.timestamp);

        _checkpointSupply(_weekTime);
    }

    function checkpointToken(IERC20 _token) external {
        uint _weekTime = _roundTimestamp(block.timestamp);
        _checkpointToken(_token, _weekTime);
    }

    function depositTokenFrom(IERC20 token, address from, uint amount) external nonReentrant requiresAuth {
        uint _weekTime = _roundTimestamp(block.timestamp);

        router.transfer(token, from, address(this), amount);
        _checkpointToken(token, _weekTime);
        _checkpointSupply(_weekTime);
    }

    function getHeadUserTokenCursor(IERC20 _token, address _user, uint _claimCursor) external view returns (uint) {
        uint _lastUserEpoch = votingEscrow.userPointEpoch(_user);
        if (_lastUserEpoch == 0) return 0;

        uint _userEpoch = 0;
        if (_userEpoch == 0) return 0;

        VotingEscrow.Point memory _userPoint = votingEscrow.getUserPointHistory(_user, _userEpoch);

        if (_claimCursor == 0) return 0;

        uint _cursor = _claimCursor;
        for (uint i = 0; i < 50; i++) {
            if (_cursor >= _userPoint.ts) {
                _userEpoch += 1;
                _userPoint = votingEscrow.getUserPointHistory(_user, _userEpoch);
            } else {
                return _cursor;
            }
        }

        return _cursor;
    }

    function _calculateDistribution(
        IERC20 _token, //
        address _user,
        uint _claimCursor,
        uint _toCursor
    ) internal view returns (uint _toDistribute) {
        _toDistribute = 0;

        if (_claimCursor >= _toCursor) return 0;

        uint _deltaCursor = _claimCursor - _toCursor;

        VotingEscrow.Point memory _oldUserPoint;

        uint _epoch = 0;
        if (_epoch == 0) return 0;

        while (_deltaCursor > 0) {
            VotingEscrow.Point memory _userPoint = votingEscrow.getUserPointHistory(_user, _epoch);

            uint _balanceOf = getBalance(_userPoint, _claimCursor);
            uint _claimable = (_balanceOf * tokensPerWeekMap[_token][_claimCursor]) / veSupply[_claimCursor];

            _toDistribute += _claimable;

            _deltaCursor -= WEEK;
        }
    }

    function getClaimable(IERC20 _token, address _account) external view returns (uint) {
        uint _claimCursor = userClaimCursorMap[_token][msg.sender];
        uint _tokenCursor = tokenCursorMap[_token];

        if (_claimCursor >= _tokenCursor) return 0;

        uint _lastUserEpoch = votingEscrow.userPointEpoch(msg.sender);
        if (_lastUserEpoch == 0) return 0;

        uint _toCursor = _roundTimestamp(block.timestamp);

        uint _amount = _calculateDistribution(_token, msg.sender, _claimCursor, _toCursor);

        return _amount;
    }

    function claim(IERC20 _token, address _receiver) external returns (uint) {
        uint _weekTime = _roundTimestamp(block.timestamp);

        _checkpointSupply(_weekTime);

        uint _claimCursor = userClaimCursorMap[_token][msg.sender];
        uint _amount = _calculateDistribution(_token, msg.sender, _claimCursor, _weekTime);

        userClaimCursorMap[_token][msg.sender] = _claimCursor;
        emit RevenueDistributor2__Claimed(msg.sender, _claimCursor, _amount);

        if (_amount > 0) {
            tokensBalanceMap[_token] -= _amount;
            _token.transfer(_receiver, _amount);
        }

        return _amount;
    }

    // Internal

    function _checkpointToken(IERC20 _token, uint _weekTime) internal {
        uint _balance = _token.balanceOf(address(this));
        uint _amountIn = _balance - tokensBalanceMap[_token];
        uint _nextWeek = _roundTimestamp(block.timestamp + WEEK);
        uint _offset = _nextWeek - _weekTime; // will underflow if _nextWeek < _weekTime
        uint _trailNextWeek = Precision.applyFactor(Precision.toFactor(_offset, WEEK), _amountIn);

        tokensBalanceMap[_token] = _balance;
        tokenCursorMap[_token] = _weekTime;

        tokensPerWeekMap[_token][_nextWeek] += _trailNextWeek;
        tokensPerWeekMap[_token][_weekTime] += _amountIn - _trailNextWeek;

        emit RevenueDistributor2__CheckpointToken(block.timestamp, _amountIn);
    }

    function _checkpointSupply(uint _weekTime) internal {
        if (timeCursor >= _weekTime) return;

        veSupply[_weekTime] = _toUint(votingEscrow.checkpoint().bias);
        timeCursor = _weekTime;
    }

    function getBalance(VotingEscrow.Point memory _point, uint _ti) internal pure returns (uint) {
        int128 _dt = int128(int(_ti - _point.ts));
        int128 _bias = _point.bias - _dt * _point.slope;

        return _bias > 0 ? uint(int(_bias)) : 0;
    }

    function _toUint(int128 _value) internal pure returns (uint) {
        return SafeCast.toUint256(int(_value));
    }

    function _roundTimestamp(uint _timestamp) private pure returns (uint) {
        // Division by zero or overflows are impossible here.
        return (_timestamp / WEEK) * WEEK;
    }

    error RevenueDistributor__NoClaimableAmount();
}
