// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC7579ActionPolicy} from "modulekit/module-bases/ERC7579ActionPolicy.sol";
import {ERC7579PolicyBase} from "modulekit/module-bases/ERC7579PolicyBase.sol";
import {IPolicy, IActionPolicy, ConfigId} from "modulekit/module-bases/interfaces/IPolicy.sol";
import {VALIDATION_SUCCESS, VALIDATION_FAILED} from "modulekit/accounts/common/interfaces/IERC7579Module.sol";
import {IEventEmitter} from "../../utils/interfaces/IEventEmitter.sol";

contract SubscriptionPolicy is ERC7579ActionPolicy {
    struct Subscription {
        uint16 allowanceRate;      // basis points (10000 = 100%)
        uint16 minAllocationRatio; // minimum allocation ratio in basis points
        uint64 expiry;             // unix timestamp
    }

    IEventEmitter public immutable eventEmitter;

    // ConfigId => multiplexer => puppet => master => subscription
    mapping(ConfigId => mapping(address => mapping(address => mapping(address => Subscription)))) internal _subscriptions;

    constructor(IEventEmitter _eventEmitter) {
        eventEmitter = _eventEmitter;
    }

    function onInstall(bytes calldata) external override {}

    function onUninstall(bytes calldata) external override {}

    function isModuleType(uint256 moduleTypeId) external pure override returns (bool) {
        return moduleTypeId == TYPE_POLICY;
    }

    function isInitialized(address) external pure override returns (bool) {
        return false;
    }

    function isInitialized(address account, ConfigId configId) external view override returns (bool) {
        return false;
    }

    function isInitialized(address account, address multiplexer, ConfigId configId) external view override returns (bool) {
        return false;
    }

    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(IActionPolicy).interfaceId || interfaceId == 0x01ffc9a7;
    }

    function initializeWithMultiplexer(
        address account,
        ConfigId configId,
        bytes calldata initData
    ) external override(ERC7579PolicyBase, IPolicy) {
        (address master, uint16 allowanceRate, uint16 minAllocationRatio, uint64 expiry) =
            abi.decode(initData, (address, uint16, uint16, uint64));

        require(allowanceRate <= 10000, "Invalid allowance rate");
        require(minAllocationRatio <= 10000, "Invalid min allocation ratio");

        _subscriptions[configId][msg.sender][account][master] = Subscription({
            allowanceRate: allowanceRate,
            minAllocationRatio: minAllocationRatio,
            expiry: expiry
        });

        eventEmitter.logEvent("Subscribe", abi.encode(configId, account, master, allowanceRate, minAllocationRatio, expiry));
    }

    function getSubscription(
        ConfigId configId,
        address multiplexer,
        address puppet,
        address master
    ) external view returns (Subscription memory) {
        return _subscriptions[configId][multiplexer][puppet][master];
    }

    function checkAction(
        ConfigId id,
        address account,
        address target,
        uint256 value,
        bytes calldata data
    ) external view override returns (uint256) {
        if (value != 0) return VALIDATION_FAILED;
        if (data.length < 68) return VALIDATION_FAILED;
        if (bytes4(data[:4]) != IERC20.transfer.selector) return VALIDATION_FAILED;

        (address recipient, uint256 amount) = abi.decode(data[4:], (address, uint256));

        Subscription memory sub = _subscriptions[id][msg.sender][account][recipient];

        if (sub.allowanceRate == 0) return VALIDATION_FAILED;
        if (block.timestamp > sub.expiry) return VALIDATION_FAILED;

        uint256 maxAllowed = (IERC20(target).balanceOf(account) * sub.allowanceRate) / 10000;
        if (amount > maxAllowed) return VALIDATION_FAILED;

        return VALIDATION_SUCCESS;
    }
}
