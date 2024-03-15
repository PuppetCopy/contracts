// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";
import {StoreController} from "../../utils/StoreController.sol";

contract PuppetStore is StoreController {
    struct Account {
        uint deposit;
        uint latestActivityTimestamp;
    }

    struct Rule {
        address trader;
        address puppet;
        bytes32 positionKey;
        uint throttleActivity;
        uint allowanceRate;
        uint expiry;
    }

    mapping(address => Account) public accountMap;
    mapping(bytes32 puppetTraderKey => Rule) public ruleMap;

    constructor(Authority _authority, address _initSetter) StoreController(_authority, _initSetter) {}

    function getAccount(address account) external view returns (Account memory) {
        return accountMap[account];
    }

    function setAccount(address _address, Account calldata _account) external isSetter {
        accountMap[_address] = _account;
    }

    function getAccountList(address[] calldata _addressList) external view returns (Account[] memory) {
        Account[] memory accounts = new Account[](_addressList.length);
        for (uint i = 0; i < _addressList.length; i++) {
            accounts[i] = accountMap[_addressList[i]];
        }
        return accounts;
    }

    function setAccountList(address[] calldata _addressList, Account[] calldata _accounts) external isSetter {
        for (uint i = 0; i < _addressList.length; i++) {
            accountMap[_addressList[i]] = _accounts[i];
        }
    }

    function removeAccount(address _account) external isSetter {
        delete accountMap[_account];
    }

    function getRule(bytes32 _key) external view returns (Rule memory) {
        return ruleMap[_key];
    }

    function setRule(Rule memory rule, bytes32 key) external isSetter {
        ruleMap[key] = rule;
    }

    function removeRule(bytes32 _key) external isSetter {
        delete ruleMap[_key];
    }

    function getRuleList(bytes32[] calldata _keys) external view returns (Rule[] memory) {
        Rule[] memory rules = new Rule[](_keys.length);
        for (uint i = 0; i < _keys.length; i++) {
            rules[i] = ruleMap[_keys[i]];
        }
        return rules;
    }


}
