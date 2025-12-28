// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC7579Account} from "modulekit/accounts/common/interfaces/IERC7579Account.sol";
import {ERC7579ActionPolicy} from "modulekit/module-bases/ERC7579ActionPolicy.sol";
import {ERC7579PolicyBase} from "modulekit/module-bases/ERC7579PolicyBase.sol";
import {IPolicy, IActionPolicy, ConfigId} from "modulekit/module-bases/interfaces/IPolicy.sol";
import {VALIDATION_SUCCESS, VALIDATION_FAILED} from "modulekit/accounts/common/interfaces/IERC7579Module.sol";
import {IEventEmitter} from "../../utils/interfaces/IEventEmitter.sol";
import {IAllocation} from "../interface/IAllocation.sol";
import {Precision} from "../../utils/Precision.sol";

contract SubscriptionPolicy is ERC7579ActionPolicy {
    struct Subscription {
        uint16 allowanceRate;
        uint16 minAllocationRatio;
        uint64 expiry;
    }

    IEventEmitter public immutable eventEmitter;
    IAllocation public immutable allocation;

    mapping(ConfigId => mapping(address => mapping(address => mapping(address => Subscription)))) internal subscriptionMap;

    constructor(IEventEmitter _eventEmitter, IAllocation _allocation) {
        eventEmitter = _eventEmitter;
        allocation = _allocation;
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

        subscriptionMap[configId][msg.sender][account][master] = Subscription({
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
        return subscriptionMap[configId][multiplexer][puppet][master];
    }

    function checkAction(
        ConfigId id,
        address puppet,
        address token,
        uint256 value,
        bytes calldata data
    ) external view override returns (uint256) {
        if (value != 0) return VALIDATION_FAILED;
        if (data.length < 68) return VALIDATION_FAILED;
        if (bytes4(data[:4]) != IERC20.transfer.selector) return VALIDATION_FAILED;

        (address masterSubaccount, uint256 amount) = abi.decode(data[4:], (address, uint256));

        Subscription memory sub = subscriptionMap[id][msg.sender][puppet][masterSubaccount];

        if (sub.allowanceRate == 0) return VALIDATION_FAILED;
        if (block.timestamp > sub.expiry) return VALIDATION_FAILED;

        uint256 puppetBalance = IERC20(token).balanceOf(puppet);
        uint256 maxAllowed = Precision.applyBasisPoints(sub.allowanceRate, puppetBalance);
        if (amount > maxAllowed) return VALIDATION_FAILED;

        address masterAccount = allocation.subaccountOwnerMap(masterSubaccount);
        if (masterAccount == address(0)) return VALIDATION_FAILED;

        bytes32 key = keccak256(abi.encodePacked(IERC20(token), IERC7579Account(masterSubaccount)));
        uint256 totalShares = allocation.totalSharesMap(key);
        uint256 masterShares = allocation.shareBalanceMap(key, masterAccount);
        uint256 puppetShares = totalShares - masterShares;

        uint256 minMasterShares = Precision.applyBasisPoints(sub.minAllocationRatio, puppetShares);
        if (masterShares < minMasterShares) return VALIDATION_FAILED;

        return VALIDATION_SUCCESS;
    }
}
