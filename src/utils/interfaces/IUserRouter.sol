// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC7579Account} from "modulekit/accounts/common/interfaces/IERC7579Account.sol";

interface IUserRouter {
    function createMaster(
        address user,
        address signer,
        IERC7579Account master,
        IERC20 baseToken,
        bytes32 name
    ) external;

    function disposeMaster(IERC7579Account master) external;

    function isDisposed(IERC7579Account master) external view returns (bool);

    function processPreCall(address msgSender, address master, uint msgValue, bytes calldata msgData)
        external
        returns (bytes memory hookData);

    function processPostCall(bytes calldata hookData) external;
}
