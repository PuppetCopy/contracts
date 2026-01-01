// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC7579Account} from "modulekit/accounts/common/interfaces/IERC7579Account.sol";

/// @notice Interface for UserRouter passthrough functions
interface IUserRouter {
    // ============ Allocation Passthrough ============

    function registerMasterSubaccount(address account, address signer, IERC7579Account subaccount, IERC20 token)
        external;

    // ============ Hook Validation ============

    function validatePreCall(address subaccount, address msgSender, uint msgValue, bytes calldata msgData)
        external
        view
        returns (bytes memory hookData);

    function settle(address subaccount, bytes calldata hookData) external;

    // ============ Position Passthrough ============

    function getPositionKeyList(bytes32 matchingKey) external view returns (bytes32[] memory);
}
