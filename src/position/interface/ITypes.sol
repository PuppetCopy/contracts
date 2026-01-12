// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

struct MasterInfo {
    address user;
    address signer;
    IERC20 baseToken;
    bytes32 name;
}

/// @notice Action parsed from stage validation
struct Action {
    bytes4 actionType;   // Action type (e.g., CREATE_ORDER, CLAIM_FUNDING)
    bytes data;          // Action-specific encoded data
}
