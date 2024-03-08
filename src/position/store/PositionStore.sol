// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";
import {StoreController} from "../../utilities/StoreController.sol";

contract PositionStore is StoreController {
    struct MirrorPosition {
        uint deposit;
        uint[] puppetAccountList;
        uint[] puppetDepositList;
    }

    mapping(address => MirrorPosition) public mpMap;

    constructor(Authority _authority, address _initSetter) StoreController(_authority, _initSetter) {}

    function getMirrorPosition(address _user) external view returns (MirrorPosition memory) {
        return mpMap[_user];
    }

    function setMirrorPosition(address _user, MirrorPosition memory _mp) external isSetter {
        mpMap[_user] = _mp;
    }
}
