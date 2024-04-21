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
        uint cursorTokenBalance = store.getCursorBalance(token, cursor);

        if (cursorTokenBalance == 0) return 0;

        uint veSupply = votingEscrow.totalSupply(cursor);
        uint balance = votingEscrow.balanceOf(user, cursor);

        return balance * cursorTokenBalance / veSupply;
    }

    function getClaimable(IERC20 token, address user) public view returns (uint amount) {
        return getClaimable(token, user, store.getUserTokenCursor(token, user), _getCursor(block.timestamp));
    }

    function getClaimable(IERC20 token, address user, uint fromCursor, uint toCursor) public view returns (uint amount) {
        if (toCursor > fromCursor) return 0;

        for (uint iCursor = fromCursor; iCursor < toCursor; iCursor += CURSOR_INTERVAL) {
            amount += getClaimableCursor(token, user, iCursor);
        }
    }

    constructor(Authority _authority, CugarStore _store, VotingEscrow _votingEscrow) Auth(address(0), _authority) {
        store = _store;
        votingEscrow = _votingEscrow;
    }

    // integration

    function increaseSeedContribution(IERC20 token, address depositor, address user, uint amountInToken) external requiresAuth {
        uint cursor = _getCursor(block.timestamp);
        store.increaseSeedContribution(token, cursor, depositor, user, amountInToken);
    }

    function increaseSeedContributionList(IERC20 token, address[] calldata userList, uint[] calldata amountList) external requiresAuth {
        uint cursor = _getCursor(block.timestamp);
        store.increaseSeedContributionList(token, cursor, msg.sender, userList, amountList);
    }

    function claim(IERC20 token, address user, address receiver) external requiresAuth returns (uint amount) {
        uint fromCursor = store.getUserTokenCursor(token, user);
        uint toCursor = _getCursor(block.timestamp);

        amount = getClaimable(token, user, fromCursor, toCursor);

        if (amount == 0) revert Cugar__NothingToClaim();

        if (fromCursor == 0) {
            uint fromCursorIntervals = CURSOR_INTERVAL * 20;
            uint fromEpoch = fromCursorIntervals > toCursor ? 0 : toCursor - fromCursorIntervals;
            store.setUserTokenCursor(token, user, fromEpoch);
        } else if (toCursor > fromCursor) {
            store.setUserTokenCursor(token, user, toCursor);
        }

        emit Cugar__Claimed(user, receiver, fromCursor, toCursor, amount);
    }
    // governance

    // https://github.com/gmx-io/gmx-synthetics/blob/main/contracts/mock/ReferralStorage.sol#L127
    function transferReferralOwnership(IGmxReferralStorage _referralStorage, bytes32 _code, address _newOwner) external requiresAuth {
        _referralStorage.setCodeOwner(_code, _newOwner);
    }

    // internal

    function _getCursor(uint _time) internal pure returns (uint) {
        return _time / CURSOR_INTERVAL * CURSOR_INTERVAL;
    }

    error Cugar__BeyondClaimableCursor(uint cursor);
    error Cugar__ZeroVeBias();
    error Cugar__NothingToClaim();
}
