// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.31;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {CoreContract} from "../utils/CoreContract.sol";
import {Error} from "../utils/Error.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";
import {IERC7579Account} from "../utils/interfaces/IERC7579Account.sol";
import {PositionUtils} from "./utils/PositionUtils.sol";

/**
 * @title PuppetAccount
 * @notice Stores puppet policy state (no validation logic)
 * @dev PuppetModule reads from here and contains validation logic
 */
contract PuppetAccount is CoreContract {
    // puppet => traderMatchingKey => policy data (format defined by module)
    mapping(address => mapping(bytes32 => bytes)) public policyMap;

    // puppet => registered
    mapping(address => bool) public registeredPuppet;

    constructor(IAuthority _authority) CoreContract(_authority, "") {}

    // ============ Registration ============

    function registerPuppet(IERC7579Account _puppet, address _module) external auth {
        if (!_puppet.isModuleInstalled(1, _module, "")) {
            revert Error.PuppetAccount__UnregisteredPuppet();
        }
        registeredPuppet[address(_puppet)] = true;
    }

    // ============ Policy Management ============

    function setPolicy(IERC7579Account _puppet, bytes32 _traderMatchingKey, bytes calldata _data) external auth {
        policyMap[address(_puppet)][_traderMatchingKey] = _data;
    }

    function removePolicy(IERC7579Account _puppet, address _trader, IERC20 _collateralToken) external auth {
        bytes32 _traderMatchingKey = PositionUtils.getTraderMatchingKey(_collateralToken, _trader);
        delete policyMap[address(_puppet)][_traderMatchingKey];

        _logEvent("PolicyRemoved", abi.encode(_puppet, _trader, _collateralToken));
    }

    function _setConfig(bytes memory) internal override {}
}
