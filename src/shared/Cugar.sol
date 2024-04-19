// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {VotingEscrow} from "./../tokenomics/VotingEscrow.sol";
import {CugarStore} from "./store/CugarStore.sol";

uint constant CURSOR_INTERVAL = 1 weeks; // all future times are rounded by week

contract Cugar is Auth, ReentrancyGuard {
    event Cugar__CheckpointToken(uint time, uint tokens);
    event Cugar__Claimed(address user, address receiver, uint claimCursor, uint amount);

    CugarStore store;
    VotingEscrow votingEscrow;

    function getClaimable(IERC20 token, address user, uint cursor) internal view returns (uint) {
        uint cursorTokenBalance = store.getCursorBalance(token, cursor);

        if (cursorTokenBalance == 0) return 0;

        uint balance = votingEscrow.balanceOf(user, cursor);
        uint veSupply = store.getCursorVeSupply(cursor);

        return balance * cursorTokenBalance / veSupply;
    }

    function getClaimableCursor(IERC20 _token, address user, uint toCursor, uint fromCursor) external view returns (uint amount) {
        if (fromCursor > toCursor) return 0;

        for (uint iCursor = fromCursor; iCursor < toCursor; iCursor += CURSOR_INTERVAL) {
            amount += getClaimable(_token, user, iCursor);
        }
    }

    function getClaimableCursor(address user, IERC20 _token) external view returns (uint) {
        uint fromCursor = store.getUserTokenCursor(_token, user);
        uint toCursor = _getCursor(block.timestamp);
        return _getClimable(_token, user, fromCursor, toCursor);
    }

    constructor(Authority _authority, CugarStore _store, VotingEscrow _votingEscrow) Auth(address(0), _authority) {
        store = _store;
        votingEscrow = _votingEscrow;
    }

    // integration

    function commit(IERC20 token, address depositor, address user, uint amountInToken) external requiresAuth {
        uint cursor = _getCursor(block.timestamp);
        store.increaseCommit(token, cursor, depositor, user, amountInToken);
    }

    function decreaseCommit(IERC20 token, address user, uint amount) external requiresAuth {
        store.decreaseCommit(token, user, amount);
    }

    function commitList(IERC20 token, address[] calldata userList, uint[] calldata amountList) external requiresAuth {
        uint cursor = _getCursor(block.timestamp);
        store.increaseCommitList(token, cursor, msg.sender, userList, amountList);
    }

    function updateCursor(IERC20 token, address user, uint amount) external requiresAuth {
        store.decreaseCommit(token, user, amount);

        uint currentCursor = _getCursor(block.timestamp);
        uint cursorVeSupply = store.getCursorVeSupply(currentCursor);
        uint userCursor = store.getUserTokenCursor(token, user);

        if (userCursor == 0) {
            store.setUserTokenCursor(token, user, currentCursor);
        }

        if (cursorVeSupply == 0) {
            uint supply = votingEscrow.totalSupply();

            if (supply == 0) revert Cugar__ZeroVeBias();
            store.setCursorVeSupply(currentCursor, supply);
        }

        emit Cugar__CheckpointToken(block.timestamp, amount);
    }

    function claim(IERC20 token, address user, address receiver) external requiresAuth returns (uint amount) {
        uint fromCursor = store.getUserTokenCursor(token, user);
        uint currentCursor = _getCursor(block.timestamp);

        if (fromCursor > currentCursor) revert Cugar__BeyondClaimableCursor(fromCursor);

        for (uint iCursor = fromCursor; iCursor < currentCursor; iCursor += CURSOR_INTERVAL) {
            uint cursorAmount = getClaimable(token, user, iCursor);

            if (cursorAmount > 0) {
                store.decreaseCursorBalance(token, iCursor, user, amount); //
            }

            amount += cursorAmount;
        }

        if (amount == 0) revert Cugar__NothingToClaim();

        store.setUserTokenCursor(token, user, currentCursor);

        emit Cugar__Claimed(user, receiver, fromCursor, amount);
    }

    // internal

    function _getCursor(uint _time) internal pure returns (uint) {
        return _time / CURSOR_INTERVAL;
    }

    function _getClimable(
        IERC20 token, //
        address user,
        uint fromCursor,
        uint toCursor
    ) internal view returns (uint amount) {
        if (fromCursor > toCursor) return 0;

        for (uint iCursor = fromCursor; iCursor < toCursor; iCursor += CURSOR_INTERVAL) {
            uint veSupply = store.getCursorVeSupply(iCursor);
            uint cursorTokenBalance = store.getCursorBalance(token, iCursor);

            if (cursorTokenBalance == 0) continue;

            uint balance = votingEscrow.balanceOf(user, iCursor);

            amount += balance * cursorTokenBalance / veSupply;
        }
    }

    error Cugar__BeyondClaimableCursor(uint cursor);
    error Cugar__ZeroVeBias();
    error Cugar__NothingToClaim();
}
