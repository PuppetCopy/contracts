// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract PuppetToken is ERC20, ERC20Burnable {
    uint private constant TOTAL_SUPPLY = 100_000_000e18;

    constructor() ERC20("Puppet Test", "PUPPET-TEST") {
        _mint(msg.sender, TOTAL_SUPPLY);
    }
}
