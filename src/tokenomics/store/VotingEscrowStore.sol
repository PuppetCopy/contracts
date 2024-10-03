// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {BankStore} from "../../shared/store/BankStore.sol";
import {Router} from "./../../shared/Router.sol";
import {Access} from "./../../utils/auth/Access.sol";
import {IAuthority} from "./../../utils/interfaces/IAuthority.sol";

contract VotingEscrowStore is BankStore {
    struct Vested {
        uint amount;
        uint remainingDuration;
        uint lastAccruedTime;
        uint accrued;
    }

    mapping(address => uint) public userBalanceMap;
    mapping(address => uint) public lockDurationMap;
    mapping(address => Vested) public vestMap;

    constructor(IAuthority _authority, Router _router) BankStore(_authority, _router) {}

    function getLockDuration(address _user) external view returns (uint) {
        return lockDurationMap[_user];
    }

    function setLockDuration(address _user, uint _duration) external auth {
        lockDurationMap[_user] = _duration;
    }

    function getVested(address _user) external view returns (Vested memory) {
        return vestMap[_user];
    }

    function setVested(address _user, Vested memory _vest) external auth {
        vestMap[_user] = _vest;
    }
}
