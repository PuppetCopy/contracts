// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import {PuppetToken} from "../tokenomics/PuppetToken.sol";
import {CoreContract} from "../utils/CoreContract.sol";
import {Error} from "../utils/Error.sol";
import {Precision} from "../utils/Precision.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {PuppetVoteToken} from "./PuppetVoteToken.sol";
import {VotingEscrowStore} from "./VotingEscrowStore.sol";

contract VotingEscrow is CoreContract {
    struct Vested {
        uint amount;
        uint remainingDuration;
        uint lastAccruedTime;
        uint accrued;
    }

    VotingEscrowStore public immutable store;
    PuppetToken public immutable token;
    PuppetVoteToken public immutable vToken;
    uint public constant MAXTIME = 106 weeks; // about 2 years

    mapping(address => uint) public lockDurationMap;
    mapping(address => Vested) public vestMap;

    struct Config {
        uint transferOutGasLimit;
        uint baseMultiplier;
    }

    Config config;

    constructor(
        IAuthority _authority,
        VotingEscrowStore _store,
        PuppetToken _token,
        PuppetVoteToken _vToken
    ) CoreContract(_authority, bytes("")) {
        store = _store;
        token = _token;
        vToken = _vToken;
    }

    function getConfig() external view returns (Config memory) {
        return config;
    }

    function getVestingCursor(
        address user
    ) public view returns (Vested memory vested) {
        vested = vestMap[user];
        uint timeElapsed = block.timestamp - vested.lastAccruedTime;
        uint accruedDelta = timeElapsed >= vested.remainingDuration
            ? vested.amount
            : (timeElapsed * vested.amount) / vested.remainingDuration;

        vested.remainingDuration = timeElapsed >= vested.remainingDuration ? 0 : vested.remainingDuration - timeElapsed;
        vested.amount -= accruedDelta;
        vested.accrued += accruedDelta;
        vested.lastAccruedTime = block.timestamp;

        return vested;
    }

    function getClaimable(
        address user
    ) external view returns (uint) {
        return getVestingCursor(user).accrued;
    }

    function calcDurationMultiplier(
        uint duration
    ) public view returns (uint) {
        uint numerator = config.baseMultiplier * duration ** 2;
        return numerator / (MAXTIME ** 2);
    }

    function getVestedBonus(uint amount, uint duration) public view returns (uint) {
        return Precision.applyFactor(calcDurationMultiplier(duration), amount);
    }

    function lock(address depositor, address user, uint amount, uint duration) external auth {
        require(amount > 0, Error.VotingEscrow__ZeroAmount());
        require(duration <= MAXTIME, Error.VotingEscrow__ExceedMaxTime());

        uint bonusAmount = getVestedBonus(amount, duration);

        store.transferIn(token, depositor, amount);
        // token.mint(address(store), bonusAmount);
        store.syncTokenBalance(token);

        _vest(user, user, bonusAmount, duration);

        uint vBalance = vToken.balanceOf(user);
        uint nextAmount = vBalance + amount;
        uint nextDuration = (vBalance * lockDurationMap[user] + amount * duration) / nextAmount;

        lockDurationMap[user] = nextDuration;
        vToken.mint(user, amount);

        _logEvent("Lock", abi.encode(depositor, user, nextAmount, nextDuration, bonusAmount));
    }

    function vest(address user, address receiver, uint amount) external auth {
        vToken.burn(user, amount);
        _vest(user, receiver, amount, lockDurationMap[user]);
    }

    function claim(address user, address receiver, uint amount) external auth {
        require(amount > 0, Error.VotingEscrow__ZeroAmount());

        Vested memory vested = getVestingCursor(user);

        require(amount <= vested.accrued, Error.VotingEscrow__ExceedingAccruedAmount(vested.accrued));

        vested.accrued -= amount;
        vestMap[user] = vested;
        store.transferOut(config.transferOutGasLimit, token, receiver, amount);

        _logEvent("Claim", abi.encode(user, receiver, amount));
    }

    function _setConfig(
        bytes memory data
    ) internal override {
        config = abi.decode(data, (Config));
    }

    function _vest(address user, address receiver, uint amount, uint duration) internal {
        if (amount == 0) revert Error.VotingEscrow__ZeroAmount();

        Vested memory vested = getVestingCursor(user);
        uint amountNext = vested.amount + amount;

        vested.remainingDuration = (vested.amount * vested.remainingDuration + amount * duration) / amountNext;
        vested.amount = amountNext;

        vestMap[user] = vested;

        _logEvent("Vest", abi.encode(user, receiver, vested));
    }
}
