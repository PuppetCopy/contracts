// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC7579Account} from "modulekit/accounts/common/interfaces/IERC7579Account.sol";

interface IAllocation {
    function totalSharesMap(bytes32 key) external view returns (uint);
    function shareBalanceMap(bytes32 key, address account) external view returns (uint);
    function masterSubaccountMap(bytes32 key) external view returns (IERC7579Account);
    function subaccountOwnerMap(address subaccount) external view returns (address);
}
