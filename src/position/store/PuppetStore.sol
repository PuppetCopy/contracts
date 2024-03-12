// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";
import {StoreController} from "../../utils/StoreController.sol";

contract PuppetStore is StoreController {
    struct Account {
        uint deposit;
        uint throttlePeriod;
        uint latestMatchTimestamp;
    }

    struct Rule {
        address trader;
        bytes32 routeKey;
        uint allowanceRate;
        uint expiry;
    }

    mapping(address => Account) public accountMap;
    mapping(bytes32 => Rule) public ruleMap;

    constructor(Authority _authority, address _initSetter) StoreController(_authority, _initSetter) {}

    function getAccount(address account) external view returns (Account memory) {
        return accountMap[account];
    }

    function getRule(bytes32 key) external view returns (Rule memory) {
        return ruleMap[key];
    }

    function setAccount(address puppet, Account calldata account) external isSetter {
        accountMap[puppet] = account;
    }

    function removeAccount(address account) external isSetter {
        delete accountMap[account];
    }

    function setRule(Rule memory rule, bytes32 key) external isSetter {
        ruleMap[key] = rule;
    }

    function removeRule(bytes32 key) external isSetter {
        delete ruleMap[key];
    }
}
