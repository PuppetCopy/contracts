// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {Permission} from "src/utils/auth/Permission.sol";
import {IAuthority} from "src/utils/interfaces/IAuthority.sol";

/// @title PuppetVoteToken
contract PuppetVoteToken is Permission, ERC20Votes {
    constructor(IAuthority _authority)
        Permission(_authority)
        ERC20("Puppet Voting Power", "vPUPPET")
        EIP712("PuppetVoteToken", "1")
    {}

    function burn(address user, uint amount) external auth {
        _burn(user, amount);
    }

    function mint(address user, uint amount) external auth {
        _mint(user, amount);
    }

    /// @notice Transfers are unsupported in this contract.
    function transfer(address, uint) public pure override returns (bool) {
        revert VotingEscrow__Unsupported();
    }

    /// @notice TransferFrom is unsupported in this contract.
    function transferFrom(address, address, uint) public pure override returns (bool) {
        revert VotingEscrow__Unsupported();
    }

    error VotingEscrow__Unsupported();
}
