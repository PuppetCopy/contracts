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
    }

    CallConfig callConfig;

    function getClaimable(IERC20 token, address user, uint cursor) internal view returns (uint) {
        uint cursorTokenBalance = callConfig.store.getCursorBalance(token, cursor);

        if (cursorTokenBalance == 0) return 0;

        uint balance = callConfig.votingEscrow.balanceOf(user, cursor);
        uint veSupply = callConfig.store.getCursorVeSupply(cursor);

        return balance * cursorTokenBalance / veSupply;
    }

    function getClaimableCursor(IERC20 _token, address user, uint toCursor, uint fromCursor) external view returns (uint amount) {
        if (fromCursor > toCursor) return 0;

        for (uint iCursor = fromCursor; iCursor < toCursor; iCursor += CURSOR_INTERVAL) {
            amount += getClaimable(_token, user, iCursor);
        }
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

    function commit(IERC20 token, address depositor, address user, uint amountInToken) external requiresAuth {
        uint cursor = _getCursor(block.timestamp + CURSOR_INTERVAL);
        callConfig.store.increaseCommit(token, cursor, depositor, user, amountInToken);
    }

    function decreaseCommit(IERC20 token, address user, uint amount) external requiresAuth {
        callConfig.store.decreaseCommit(token, user, amount);
    }

    function commitList(IERC20 token, address[] calldata userList, uint[] calldata amountList) external requiresAuth {
        uint cursor = _getCursor(block.timestamp + CURSOR_INTERVAL);
        callConfig.store.increaseCommitList(token, cursor, msg.sender, userList, amountList);
    }

    function updateCursor(IERC20 token, address user, uint amount) external requiresAuth {
        callConfig.store.decreaseCommit(token, user, amount);

        uint cursor = _getCursor(block.timestamp + CURSOR_INTERVAL);
        uint cursorVeSupply = callConfig.store.getCursorVeSupply(cursor);
        uint userCursor = callConfig.store.getUserTokenCursor(token, user);

        if (userCursor == 0) {
            callConfig.store.setUserTokenCursor(token, user, cursor);
        }

        if (cursorVeSupply == 0) {
            uint supply = callConfig.votingEscrow.totalSupply();

            if (supply == 0) revert Cugar__ZeroVeBias();
            callConfig.store.setCursorVeSupply(cursor, supply);
        }

        emit Cugar__CheckpointToken(block.timestamp, amount);
    }

    function claim(IERC20 token, address user, address receiver) external requiresAuth returns (uint amount) {
        uint fromCursor = callConfig.store.getUserTokenCursor(token, user);
        uint toCursor = _getCursor(block.timestamp);

        if (fromCursor > toCursor) revert Cugar__BeyondClaimableCursor(fromCursor);

        for (uint iCursor = fromCursor; iCursor < toCursor; iCursor += CURSOR_INTERVAL) {
            uint cursorAmount = getClaimable(token, user, iCursor);

            if (cursorAmount > 0) callConfig.store.decreaseCursorBalance(token, iCursor, user, amount);

            amount += cursorAmount;
        }

        if (amount == 0) revert Cugar__NothingToClaim();

        callConfig.store.setUserTokenCursor(token, user, toCursor);

        emit Cugar__Claimed(user, receiver, fromCursor, amount);
    }

    // governance

    function setConfig(CallConfig memory _callConfig) external requiresAuth {
        _setConfig(_callConfig);
    }

    // internal

    function _getCursor(uint _time) internal pure returns (uint) {
        return (_time / CURSOR_INTERVAL) * CURSOR_INTERVAL;
    }

    function _getClimable(
        IERC20 token, //
        address user,
        uint fromCursor,
        uint toCursor
    ) internal view returns (uint amount) {
        if (fromCursor > toCursor) return 0;

        for (uint iCursor = fromCursor; iCursor < toCursor; iCursor += CURSOR_INTERVAL) {
            uint veSupply = callConfig.store.getCursorVeSupply(iCursor);
            uint cursorTokenBalance = callConfig.store.getCursorBalance(token, iCursor);

            if (cursorTokenBalance == 0) continue;

            uint balance = callConfig.votingEscrow.balanceOf(user, iCursor);

            amount += balance * cursorTokenBalance / veSupply;
        }
    }

    function _setConfig(CallConfig memory _callConfig) internal {
        callConfig = _callConfig;

        emit Cugar__SetConfig(block.timestamp, callConfig);
    }

    error Cugar__BeyondClaimableCursor(uint cursor);
    error Cugar__ZeroVeBias();
    error Cugar__NothingToClaim();
}
