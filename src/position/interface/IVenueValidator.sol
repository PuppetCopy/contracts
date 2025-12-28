// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC7579Account} from "modulekit/accounts/common/interfaces/IERC7579Account.sol";

interface IVenueValidator {
    struct PositionInfo {
        bytes32 positionKey;
        uint256 netValue;
    }

    function validate(
        IERC7579Account subaccount,
        IERC20 token,
        uint256 amount,
        bytes calldata callData
    ) external view;

    function getPositionNetValue(bytes32 positionKey) external view returns (uint256);

    function getPositionInfo(IERC7579Account subaccount, bytes calldata callData) external view returns (PositionInfo memory);
}
