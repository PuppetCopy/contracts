// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.31;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC7579ActionPolicy} from "modulekit/module-bases/ERC7579ActionPolicy.sol";
import {ERC7579PolicyBase} from "modulekit/module-bases/ERC7579PolicyBase.sol";
import {IPolicy, IActionPolicy, ConfigId} from "modulekit/module-bases/interfaces/IPolicy.sol";
import {VALIDATION_SUCCESS, VALIDATION_FAILED} from "erc7579/interfaces/IERC7579Module.sol";
import {IPuppetPolicy} from "./IPuppetPolicy.sol";

/**
 * @title AllowanceRatePolicy
 * @notice Smart Sessions policy that limits transfers to a percentage of balance
 */
contract AllowanceRatePolicy is ERC7579ActionPolicy, IPuppetPolicy {
    // ConfigId => multiplexer => account => allowance rate (basis points, 10000 = 100%)
    mapping(ConfigId => mapping(address => mapping(address => uint16))) internal _allowanceRate;

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
        return _allowanceRate[configId][msg.sender][account] > 0;
    }

    function isInitialized(
        address account,
        address multiplexer,
        ConfigId configId
    ) external view override returns (bool) {
        return _allowanceRate[configId][multiplexer][account] > 0;
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
        uint16 allowanceRate = abi.decode(initData, (uint16));
        require(allowanceRate > 0 && allowanceRate <= 10000, "Invalid rate");

        _allowanceRate[configId][msg.sender][account] = allowanceRate;
        emit PolicySet(configId, msg.sender, account);
    }

    // ============ IActionPolicy ============

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

        uint16 allowanceRate = _allowanceRate[id][msg.sender][account];
        if (allowanceRate == 0) return VALIDATION_FAILED;

        (, uint256 amount) = abi.decode(data[4:], (address, uint256));
        uint256 maxAllowed = (IERC20(target).balanceOf(account) * allowanceRate) / 10000;

        if (amount > maxAllowed) return VALIDATION_FAILED;

        return VALIDATION_SUCCESS;
    }
}
