// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";
import {StoreController} from "../../utilities/StoreController.sol";

contract PuppetStore is StoreController {
    struct PuppetAccount {
        uint deposit;
        uint throttleMatchingPeriod;
        uint latestMatchTimestamp;
    }

    struct PuppetTraderSubscription {
        address trader;
        bytes32 routeKey;
        uint allowanceFactor;
        uint expiry;
    }

    mapping(address => PuppetAccount) public puppetAccountMap;
    mapping(bytes32 => PuppetTraderSubscription) public puppetTraderSubscriptionMap;

    constructor(Authority _authority, address _initSetter) StoreController(_authority, _initSetter) {}

    function getPuppetAccount(address account) external view returns (PuppetAccount memory) {
        return puppetAccountMap[account];
    }

    function getPuppetTraderSubscription(bytes32 subscriptionKey) external view returns (PuppetTraderSubscription memory) {
        return puppetTraderSubscriptionMap[subscriptionKey];
    }

    function setPuppetAccount(address puppet, PuppetAccount calldata account) external isSetter {
        puppetAccountMap[puppet] = account;
    }

    function removePuppetAccount(address account) external isSetter {
        delete puppetAccountMap[account];
    }

    function setPuppetTraderSubscription(PuppetTraderSubscription memory subscription, bytes32 subscriptionKey) external isSetter {
        puppetTraderSubscriptionMap[subscriptionKey] = subscription;
    }

    function removePuppetTraderSubscription(bytes32 subscriptionKey) external isSetter {
        delete puppetTraderSubscriptionMap[subscriptionKey];
    }
}
