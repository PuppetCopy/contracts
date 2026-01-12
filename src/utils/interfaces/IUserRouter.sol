// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {IERC7579Account} from "modulekit/accounts/common/interfaces/IERC7579Account.sol";

interface IUserRouter {
    function isRegistered(IERC7579Account master) external view returns (bool);
}
