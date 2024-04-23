// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IGmxReferralStorage} from "./../position/interface/IGmxReferralStorage.sol";
import {VotingEscrow} from "./../tokenomics/VotingEscrow.sol";
import {CugarStore} from "./store/CugarStore.sol";

uint constant CURSOR_INTERVAL = 1 weeks; // all future times are rounded by week

contract Cugar is Auth, ReentrancyGuard {
    event Cugar__CheckpointToken(uint time, uint tokens);
    event Cugar__Claimed(address user, address receiver, uint fromCursor, uint toCursor, uint amount);

    CugarStore store;
    VotingEscrow votingEscrow;

    function getClaimableCursor(IERC20 token, address user, uint cursor) public view returns (uint) {
        uint balance = votingEscrow.balanceOf(user, cursor);

        if (balance == 0) return 0;

        (uint veSupply, uint cursorTokenBalance) = store.getCursorVeSupplyAndBalance(token, cursor);

        if (veSupply == 0) return 0;

        return balance * cursorTokenBalance / veSupply;
    }

    function getClaimable(IERC20 token, address user) public view returns (uint amount) {
        uint toCursor = _getCursor(block.timestamp);
        uint fromCursor = getUserTokenCursor(token, user);

        return getClaimable(token, user, fromCursor, toCursor);
    }

    function getClaimable(IERC20 token, address user, uint fromCursor, uint toCursor) public view returns (uint amount) {
        if (fromCursor > toCursor) return 0;

        for (uint iCursor = fromCursor; iCursor < toCursor; iCursor += CURSOR_INTERVAL) {
            amount += getClaimableCursor(token, user, iCursor);
        }
    }

    function getUserTokenCursor(IERC20 token, address user) public view returns (uint) {
        uint fromCursor = store.getUserTokenCursor(token, user);
        if (fromCursor == 0) {
            return _getCursor(votingEscrow.userPointHistoryTs(user, 1));
        }

        return fromCursor;
    }

    constructor(Authority _authority, CugarStore _store, VotingEscrow _votingEscrow) Auth(address(0), _authority) {
        store = _store;
        votingEscrow = _votingEscrow;
    }

    // integration

    function increaseSeedContribution(IERC20 token, address user, uint amountInToken) external requiresAuth {
        uint cursor = _getCursor(block.timestamp);

        store.increaseUserSeedContribution(token, cursor, msg.sender, user, amountInToken);
    }

    function contribute(IERC20 token, address user, uint amountInToken) external requiresAuth {
        store.decreaseUserSeedContribution(token, user, amountInToken);

        uint cursor = _getCursor(block.timestamp);
        uint veSupply = votingEscrow.totalSupply(cursor);
        votingEscrow.getLastPointHistory();
        store.setVeSupply(token, cursor, veSupply);
    }

    function increaseSeedContributionList(IERC20 token, address[] calldata userList, uint[] calldata amountList) external requiresAuth {
        uint cursor = _getCursor(block.timestamp);

        store.increaseUserSeedContributionList(token, cursor, msg.sender, userList, amountList);
    }

    function claim(IERC20 token, address user, address receiver) external requiresAuth returns (uint amount) {
        uint fromCursor = getUserTokenCursor(token, user);
        uint toCursor = _getCursor(block.timestamp);

        amount = getClaimable(token, user, fromCursor, toCursor);

        if (amount == 0) revert Cugar__NothingToClaim();
        if (toCursor > fromCursor) {
            store.setUserTokenCursor(token, user, toCursor);
        }

        store.transferOut(token, receiver, amount);

        emit Cugar__Claimed(user, receiver, fromCursor, toCursor, amount);
    }
    // governance

    // https://github.com/gmx-io/gmx-synthetics/blob/main/contracts/mock/ReferralStorage.sol#L127
    function transferReferralOwnership(IGmxReferralStorage _referralStorage, bytes32 _code, address _newOwner) external requiresAuth {
        _referralStorage.setCodeOwner(_code, _newOwner);
    }

    // internal

    function _getCursor(uint _time) internal pure returns (uint) {
        return (_time / CURSOR_INTERVAL) * CURSOR_INTERVAL;
    }

    error Cugar__BeyondClaimableCursor(uint cursor);
    error Cugar__ZeroVeBias();
    error Cugar__NothingToClaim();
}
