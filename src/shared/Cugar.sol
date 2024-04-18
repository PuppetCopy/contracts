// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {VotingEscrow} from "./../tokenomics/VotingEscrow.sol";
import {CugarStore} from "./store/CugarStore.sol";

contract Cugar is Auth, ReentrancyGuard {
    uint private constant CURSOR_INTERVAL = 1 weeks; // all future times are rounded by week

    event Cugar__SetConfig(uint timestmap, CallConfig callConfig);
    event Cugar__CheckpointToken(uint time, uint tokens);
    event Cugar__Claimed(address user, address receiver, uint claimCursor, uint amount);

    struct CallConfig {
        CugarStore store;
        VotingEscrow votingEscrow;
        uint cursorInterval;
    }

    CallConfig callConfig;

    function getList(IERC20 token, address[] calldata userList) external view returns (uint _totalAmount, uint[] memory _userCommitList) {
        return callConfig.store.getCommitList(token, userList);
    }

    function getClaimable(IERC20 _token, address user, uint fromCursor, uint toCursor) external view returns (uint) {
        return _getClimable(_token, user, fromCursor, toCursor);
    }

    function getClaimableCursor(address user, IERC20 _token) external view returns (uint) {
        uint fromCursor = callConfig.store.getUserTokenCursor(_token, user);
        uint toCursor = _getCursor(block.timestamp);
        return _getClimable(_token, user, fromCursor, toCursor);
    }

    constructor(Authority _authority, CallConfig memory _config) Auth(address(0), _authority) {
        _setConfig(_config);
    }

    // integration

    function decreaseCommit(IERC20 token, address user, uint amount) external requiresAuth {
        callConfig.store.decreaseCommit(token, user, amount);
    }

    function commit(IERC20 token, address user, uint amountInToken) external requiresAuth {
        // uint _nextCursor = _roundTimestamp(block.timestamp + WEEK);
        callConfig.store.increaseCommit(token, user, user, amountInToken);
    }

    function commitList(IERC20 token, address[] calldata userList, uint[] calldata amountList) external requiresAuth {
        // uint _nextCursor = _roundTimestamp(block.timestamp + WEEK);
        callConfig.store.increaseCommitList(token, msg.sender, userList, amountList);
    }

    function updateCursor(IERC20 token, uint amount) external requiresAuth {
        if (amount == 0) revert Cugar__ZeroValue();

        uint cursor = _getCursor(block.timestamp);
        uint cursorVeSupply = callConfig.store.getCursorVeSupply(cursor);

        if (cursorVeSupply == 0) {
            uint supply = callConfig.votingEscrow.totalSupply();

            if (supply == 0) revert Cugar__ZeroVeBias();

            uint cummulativeCursorBalance = callConfig.store.getCummulativeCursorBalance(token);

            callConfig.store.setCursorVeSupply(cursor, supply);
            callConfig.store.setCursorBalance(token, cursor, cummulativeCursorBalance);
        }

        emit Cugar__CheckpointToken(block.timestamp, amount);
    }

    function claim(IERC20 token, address user, address receiver) external requiresAuth {
        uint _weekTime = _getCursor(block.timestamp);

        uint fromCursor = callConfig.store.getUserTokenCursor(token, user);
        uint toCursor = _getCursor(block.timestamp);

        if (fromCursor >= toCursor) revert Cugar__BeyondClaimableCursor(fromCursor);

        uint amount = _getClimable(token, user, fromCursor, toCursor);

        callConfig.store.setUserTokenCursor(token, user, _weekTime);

        if (amount == 0) revert Cugar__NothingToClaim();

        emit Cugar__Claimed(user, receiver, fromCursor, amount);

        callConfig.store.decreaseCummulativeCursorBalance(token, receiver, amount);
    }

    // governance

    function setConfig(CallConfig memory _callConfig) external requiresAuth {
        _setConfig(_callConfig);
    }

    // internal

    function _getCursor(uint _time) private pure returns (uint) {
        return (_time / CURSOR_INTERVAL) * CURSOR_INTERVAL;
    }

    function _getClimable(
        IERC20 _token, //
        address _user,
        uint fromCursor,
        uint toCursor
    ) internal view returns (uint claimable) {
        if (fromCursor >= toCursor) return 0;

        uint cursorDelta = toCursor - fromCursor;

        for (uint iCursor = fromCursor; iCursor < cursorDelta; iCursor += CURSOR_INTERVAL) {
            uint veSupply = callConfig.store.getVeSupply(fromCursor);
            uint cursorTokenBalance = callConfig.store.getCursorBalance(_token, fromCursor);
            uint balance = callConfig.votingEscrow.balanceOf(_user, iCursor);

            claimable += balance * cursorTokenBalance / veSupply;
        }
    }

    function _setConfig(CallConfig memory _callConfig) internal {
        callConfig = _callConfig;

        emit Cugar__SetConfig(block.timestamp, callConfig);
    }

    error Cugar__InvalidInputLength();
    error Cugar__UnauthorizedRevenueSource();
    error Cugar__ZeroValue();
    error Cugar__BeyondClaimableCursor(uint cursor);
    error Cugar__ZeroVeBias();
    error Cugar__NothingToClaim();
}
