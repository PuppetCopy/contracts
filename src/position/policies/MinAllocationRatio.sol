// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC7579ActionPolicy} from "modulekit/module-bases/ERC7579ActionPolicy.sol";
import {ERC7579PolicyBase} from "modulekit/module-bases/ERC7579PolicyBase.sol";
import {IPolicy, IActionPolicy, ConfigId} from "modulekit/module-bases/interfaces/IPolicy.sol";
import {VALIDATION_SUCCESS, VALIDATION_FAILED} from "modulekit/accounts/common/interfaces/IERC7579Module.sol";
import {Allocation} from "../Allocation.sol";
import {Precision} from "../../utils/Precision.sol";
import {IEventEmitter} from "../../utils/interfaces/IEventEmitter.sol";

/**
 * @title MinAllocationRatio
 * @notice Smart Sessions policy requiring master's share ratio vs puppets
 * @dev ratio = masterShares / puppetShares
 */
contract MinAllocationRatio is ERC7579ActionPolicy {
    Allocation public immutable allocation;
    IEventEmitter public immutable eventEmitter;

    // ConfigId => multiplexer => account => minimum ratio (in FLOAT_PRECISION)
    mapping(ConfigId => mapping(address => mapping(address => uint))) internal _minRatio;

    // ConfigId => multiplexer => account => collateral token
    mapping(ConfigId => mapping(address => mapping(address => IERC20))) internal _collateralToken;

    constructor(Allocation _allocation, IEventEmitter _eventEmitter) {
        allocation = _allocation;
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
        return _minRatio[configId][msg.sender][account] > 0;
    }

    function isInitialized(
        address account,
        address multiplexer,
        ConfigId configId
    ) external view override returns (bool) {
        return _minRatio[configId][multiplexer][account] > 0;
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
        (uint minRatio, IERC20 collateralToken) = abi.decode(initData, (uint, IERC20));
        _minRatio[configId][msg.sender][account] = minRatio;
        _collateralToken[configId][msg.sender][account] = collateralToken;
        eventEmitter.logEvent("PolicySet", abi.encode(configId, msg.sender, account, minRatio, collateralToken));
    }

    // ============ IActionPolicy ============

    function checkAction(
        ConfigId id,
        address account,
        address,
        uint256 value,
        bytes calldata data
    ) external view override returns (uint256) {
        if (value != 0) return VALIDATION_FAILED;
        if (data.length < 68) return VALIDATION_FAILED;
        if (bytes4(data[:4]) != IERC20.transfer.selector) return VALIDATION_FAILED;

        address master = abi.decode(data[4:36], (address));

        uint minRatio = _minRatio[id][msg.sender][account];
        IERC20 collateralToken = _collateralToken[id][msg.sender][account];

        bytes32 key = keccak256(abi.encode(collateralToken, master));

        uint masterShares = allocation.userShares(key, master);
        uint totalShares = allocation.totalShares(key);
        uint puppetShares = totalShares - masterShares;

        if (puppetShares == 0) return VALIDATION_SUCCESS;

        uint ratio = Precision.toFactor(masterShares, puppetShares);

        if (ratio < minRatio) return VALIDATION_FAILED;

        return VALIDATION_SUCCESS;
    }
}
