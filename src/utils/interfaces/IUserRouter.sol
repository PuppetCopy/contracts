// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC7579Account} from "modulekit/accounts/common/interfaces/IERC7579Account.sol";

/// @notice Interface for UserRouter passthrough functions
interface IUserRouter {
    // ============ Allocation Passthrough ============

    /// @notice Register a master subaccount (token chosen at deposit time)
    function registerMasterSubaccount(
        address account,
        address signer,
        IERC7579Account subaccount,
        bytes32 name
    ) external;

    // ============ Hook Validation ============

    function processPreCall(address master, address subaccount, uint msgValue, bytes calldata msgData)
        external
        returns (bytes memory hookData);

    function processPostCall(address subaccount, bytes calldata hookData) external view;

    // ============ Position Passthrough ============

    function getPositionKeyList(bytes32 matchingKey) external view returns (bytes32[] memory);
}
