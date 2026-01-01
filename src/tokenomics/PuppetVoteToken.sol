// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

import {Error} from "../utils/Error.sol";
import {Permission} from "../utils/auth/Permission.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";

/// @title PuppetVoteToken
contract PuppetVoteToken is Permission, ERC20Votes, ERC165 {
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
        revert Error.PuppetVoteToken__Unsupported();
    }

    /// @notice TransferFrom is unsupported in this contract.
    function transferFrom(address, address, uint) public pure override returns (bool) {
        revert Error.PuppetVoteToken__Unsupported();
    }

    // Modify the supportsInterface function
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165) returns (bool) {
        return interfaceId == type(IVotes).interfaceId || super.supportsInterface(interfaceId);
    }
}
