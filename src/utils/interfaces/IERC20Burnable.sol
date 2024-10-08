// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {IERC20Mintable} from "./IERC20Mintable.sol";

interface IERC20Burnable is IERC20Mintable {
    function mint(address _receiver, uint _amount) external returns (uint);
}
