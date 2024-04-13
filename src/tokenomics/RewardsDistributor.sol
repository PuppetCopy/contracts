// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.24;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {VotingEscrow} from "./VotingEscrow.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/*
 * @title Curve Fee Distribution modified for ve(3,3) emissions
 * @author Curve Finance, andrecronje
 * @author velodrome.finance, @figs999, @pegahcarter
 * @license MIT
 */
contract RewardsDistributor {
    using SafeERC20 for IERC20;

    uint public constant WEEK = 7 * 86400;

    uint public startTime;
    mapping(uint => uint) public timeCursorOf;

    uint public lastTokenTime;
    uint[1000000000000000] public tokensPerWeek;

    VotingEscrow public immutable ve;
    address public token;
    address public minter;
    uint public tokenLastBalance;

    constructor(address _ve) {
        uint _t = (block.timestamp / WEEK) * WEEK;
        startTime = _t;
        lastTokenTime = _t;
        ve = VotingEscrow(_ve);
        address _token = ve.token();
        token = _token;
        minter = msg.sender;
        IERC20(_token).safeApprove(_ve, type(uint).max);
    }

    function _checkpointToken() internal {
        uint tokenBalance = IERC20(token).balanceOf(address(this));
        uint toDistribute = tokenBalance - tokenLastBalance;
        tokenLastBalance = tokenBalance;

        uint t = lastTokenTime;
        uint sinceLast = block.timestamp - t;
        lastTokenTime = block.timestamp;
        uint thisWeek = (t / WEEK) * WEEK;
        uint nextWeek = 0;
        uint timestamp = block.timestamp;

        for (uint i = 0; i < 20; i++) {
            nextWeek = thisWeek + WEEK;
            if (timestamp < nextWeek) {
                if (sinceLast == 0 && timestamp == t) {
                    tokensPerWeek[thisWeek] += toDistribute;
                } else {
                    tokensPerWeek[thisWeek] += (toDistribute * (timestamp - t)) / sinceLast;
                }
                break;
            } else {
                if (sinceLast == 0 && nextWeek == t) {
                    tokensPerWeek[thisWeek] += toDistribute;
                } else {
                    tokensPerWeek[thisWeek] += (toDistribute * (nextWeek - t)) / sinceLast;
                }
            }
            t = nextWeek;
            thisWeek = nextWeek;
        }
        emit CheckpointToken(timestamp, toDistribute);
    }

    function checkpointToken() external {
        if (msg.sender != minter) revert NotMinter();
        _checkpointToken();
    }

    function _claim(uint _tokenId, uint _lastTokenTime) internal returns (uint) {
        (uint toDistribute, uint epochStart, uint weekCursor) = _claimable(_tokenId, _lastTokenTime);
        timeCursorOf[_tokenId] = weekCursor;
        if (toDistribute == 0) return 0;

        emit Claimed(_tokenId, epochStart, weekCursor, toDistribute);
        return toDistribute;
    }

    function _claimable(uint _tokenId, uint _lastTokenTime) internal view returns (uint toDistribute, uint weekCursorStart, uint weekCursor) {
        uint _startTime = startTime;
        weekCursor = timeCursorOf[_tokenId];
        weekCursorStart = weekCursor;

        // case where token does not exist
        uint maxUserEpoch = ve.userPointEpoch(_tokenId);
        if (maxUserEpoch == 0) return (0, weekCursorStart, weekCursor);

        // case where token exists but has never been claimed
        if (weekCursor == 0) {
            VotingEscrow.UserPoint memory userPoint = ve.userPointHistory(_tokenId, 1);
            weekCursor = (userPoint.ts / WEEK) * WEEK;
            weekCursorStart = weekCursor;
        }
        if (weekCursor >= _lastTokenTime) return (0, weekCursorStart, weekCursor);
        if (weekCursor < _startTime) weekCursor = _startTime;

        for (uint i = 0; i < 50; i++) {
            if (weekCursor >= _lastTokenTime) break;

            uint balance = ve.balanceOfNFTAt(_tokenId, weekCursor + WEEK - 1);
            uint supply = ve.totalSupplyAt(weekCursor + WEEK - 1);
            supply = supply == 0 ? 1 : supply;
            toDistribute += (balance * tokensPerWeek[weekCursor]) / supply;
            weekCursor += WEEK;
        }
    }

    function claimable(uint _tokenId) external view returns (uint claimable_) {
        uint _lastTokenTime = (lastTokenTime / WEEK) * WEEK;
        (claimable_,,) = _claimable(_tokenId, _lastTokenTime);
    }

    function claim(uint _tokenId) external returns (uint) {
        // if (IMinter(minter).activePeriod() < ((block.timestamp / WEEK) * WExEK)) revert UpdatePeriod();
        if (ve.escrowType(_tokenId) == VotingEscrow.EscrowType.LOCKED) revert NotManagedOrNormalNFT();
        uint _timestamp = block.timestamp;
        uint _lastTokenTime = lastTokenTime;
        _lastTokenTime = (_lastTokenTime / WEEK) * WEEK;
        uint amount = _claim(_tokenId, _lastTokenTime);
        if (amount != 0) {
            VotingEscrow.LockedBalance memory _locked = ve.locked(_tokenId);
            if (_timestamp >= _locked.end && !_locked.isPermanent) {
                address _owner = ve.ownerOf(_tokenId);
                IERC20(token).safeTransfer(_owner, amount);
            } else {
                ve.depositFor(_tokenId, amount);
            }
            tokenLastBalance -= amount;
        }
        return amount;
    }

    function claimMany(uint[] calldata _tokenIds) external returns (bool) {
        // if (IMinter(minter).activePeriod() < ((block.timestamp / WEEK) * WEEK)) revert UpdatePeriod();
        uint _timestamp = block.timestamp;
        uint _lastTokenTime = lastTokenTime;
        _lastTokenTime = (_lastTokenTime / WEEK) * WEEK;
        uint total = 0;
        uint _length = _tokenIds.length;

        for (uint i = 0; i < _length; i++) {
            uint _tokenId = _tokenIds[i];
            if (ve.escrowType(_tokenId) == VotingEscrow.EscrowType.LOCKED) revert NotManagedOrNormalNFT();
            if (_tokenId == 0) break;
            uint amount = _claim(_tokenId, _lastTokenTime);
            if (amount != 0) {
                VotingEscrow.LockedBalance memory _locked = ve.locked(_tokenId);
                if (_timestamp >= _locked.end && !_locked.isPermanent) {
                    address _owner = ve.ownerOf(_tokenId);
                    IERC20(token).safeTransfer(_owner, amount);
                } else {
                    ve.depositFor(_tokenId, amount);
                }
                total += amount;
            }
        }
        if (total != 0) {
            tokenLastBalance -= total;
        }

        return true;
    }

    function setMinter(address _minter) external {
        if (msg.sender != minter) revert NotMinter();
        minter = _minter;
    }
}
