// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {Auth} from "./../../utils/access/Auth.sol";
import {IAuthority} from "./../../utils/interfaces/IAuthority.sol";

contract VotingEscrowStore is Auth {
    struct Lock {
        uint amount;
        uint duration;
    }

    struct Vest {
        uint amount;
        uint remainingDuration;
        uint lastAccruedTime;
        uint accrued;
    }

    mapping(address => Lock) public lockMap;
    mapping(address => Vest) public vestMap;

    constructor(IAuthority _authority) Auth(_authority) {}

    function getLock(address _user) external view returns (Lock memory) {
        return lockMap[_user];
    }

    function setLock(address _user, Lock memory _lock) external auth {
        lockMap[_user] = _lock;
    }

    function getVest(address _user) external view returns (Vest memory) {
        return vestMap[_user];
    }

    function setVest(address _user, Vest memory _vest) external auth {
        vestMap[_user] = _vest;
    }
}
