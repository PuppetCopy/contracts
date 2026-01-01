// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC7579Account, Execution} from "modulekit/accounts/common/interfaces/IERC7579Account.sol";

interface IVenueValidator {
    struct PositionInfo {
        bytes32 positionKey;
        uint netValue;
    }

    // ============ Hook Validation ============

    /// @notice Validate single execution, return hookData for postCheck
    function validatePreCallSingle(address subaccount, address target, uint value, bytes calldata callData)
        external
        view
        returns (bytes memory hookData);

    /// @notice Validate batch execution, return hookData for postCheck
    /// @dev Venue can validate order of operations (e.g., approve before createOrder)
    function validatePreCallBatch(address subaccount, Execution[] calldata executions)
        external
        view
        returns (bytes memory hookData);

    /// @notice Process after execution using hookData from preCheck (can mutate state)
    function processPostCall(address subaccount, bytes calldata hookData) external;

    // ============ Position Info ============

    function getPositionNetValue(bytes32 positionKey) external view returns (uint);

    function getPositionInfo(IERC7579Account subaccount, bytes calldata callData)
        external
        view
        returns (PositionInfo memory);
}
