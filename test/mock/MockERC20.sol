// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockERC20
 * @dev A generic mock ERC20 that can also function as WNT
 * This contract inherits OpenZeppelin's ERC20 and adds:
 * - Configurable decimals
 * - Public mint/burn functions for testing
 * - deposit/withdraw functions for WNT compatibility
 */
contract MockERC20 is ERC20 {
    uint8 private _decimals;

    constructor(string memory name, string memory symbol, uint8 decimals_) ERC20(name, symbol) {
        _decimals = decimals_;
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function mint(address to, uint amount) public {
        _mint(to, amount);
    }

    function burn(address from, uint amount) public {
        _burn(from, amount);
    }

    // IWNT compatibility functions
    function deposit() public payable {
        _mint(msg.sender, msg.value);
    }

    function withdraw(
        uint amount
    ) public {
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");
        _burn(msg.sender, amount);
        payable(msg.sender).transfer(amount);
    }
}
