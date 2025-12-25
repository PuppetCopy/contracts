// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.31;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC7579ActionPolicy} from "modulekit/module-bases/ERC7579ActionPolicy.sol";
import {ERC7579PolicyBase} from "modulekit/module-bases/ERC7579PolicyBase.sol";
import {IPolicy, IActionPolicy, ConfigId} from "modulekit/module-bases/interfaces/IPolicy.sol";
import {VALIDATION_SUCCESS, VALIDATION_FAILED} from "erc7579/interfaces/IERC7579Module.sol";
import {IEventEmitter} from "../../utils/interfaces/IEventEmitter.sol";

/**
 * @title ThrottlePolicy
 * @notice Smart Sessions policy that enforces minimum time between transfers per recipient
 */
contract ThrottlePolicy is ERC7579ActionPolicy {
    IEventEmitter public immutable eventEmitter;

    // ConfigId => multiplexer => account => throttle period (seconds)
    mapping(ConfigId => mapping(address => mapping(address => uint32))) internal _throttlePeriod;

    // ConfigId => multiplexer => account => recipient => last activity timestamp
    mapping(ConfigId => mapping(address => mapping(address => mapping(address => uint32)))) internal _lastActivity;

    constructor(IEventEmitter _eventEmitter) {
        eventEmitter = _eventEmitter;
    }

    // ============ ERC7579 Module ============

    function onInstall(bytes calldata) external override {}

    function onUninstall(bytes calldata) external override {}

    function isModuleType(uint256 moduleTypeId) external pure override returns (bool) {
        return moduleTypeId == TYPE_POLICY;
    }

    function isInitialized(address) external pure override returns (bool) {
        return false;
    }

    function isInitialized(address account, ConfigId configId) external view override returns (bool) {
        return _throttlePeriod[configId][msg.sender][account] > 0;
    }

    function isInitialized(
        address account,
        address multiplexer,
        ConfigId configId
    ) external view override returns (bool) {
        return _throttlePeriod[configId][multiplexer][account] > 0;
    }

    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(IActionPolicy).interfaceId || interfaceId == 0x01ffc9a7;
    }

    // ============ IPolicy ============

    function initializeWithMultiplexer(
        address account,
        ConfigId configId,
        bytes calldata initData
    ) external override(ERC7579PolicyBase, IPolicy) {
        uint32 throttlePeriod = abi.decode(initData, (uint32));
        _throttlePeriod[configId][msg.sender][account] = throttlePeriod;
        eventEmitter.logEvent("PolicySet", abi.encode(configId, msg.sender, account, throttlePeriod));
    }

    // ============ IActionPolicy ============

    function checkAction(
        ConfigId id,
        address account,
        address,
        uint256 value,
        bytes calldata data
    ) external override returns (uint256) {
        if (value != 0) return VALIDATION_FAILED;
        if (data.length < 68) return VALIDATION_FAILED;
        if (bytes4(data[:4]) != IERC20.transfer.selector) return VALIDATION_FAILED;

        address recipient = abi.decode(data[4:36], (address));

        uint32 throttlePeriod = _throttlePeriod[id][msg.sender][account];
        uint32 lastActivity = _lastActivity[id][msg.sender][account][recipient];

        if (block.timestamp < lastActivity + throttlePeriod) {
            return VALIDATION_FAILED;
        }

        _lastActivity[id][msg.sender][account][recipient] = uint32(block.timestamp);

        return VALIDATION_SUCCESS;
    }
}
