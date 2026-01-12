// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.33;

import {ERC6909} from "solady/tokens/ERC6909.sol";
import {CoreContract} from "../utils/CoreContract.sol";
import {Error} from "../utils/Error.sol";
import {IAuthority} from "../utils/interfaces/IAuthority.sol";

/// @title Compact
/// @notice Minimal ERC-6909 share accounting
/// @dev Shares are minted on allocation, burned lazily by attestor
contract Compact is ERC6909, CoreContract {

    constructor(IAuthority _authority) CoreContract(_authority, "") {}

    /// @notice Authorized mint (for Allocate contract)
    function mint(address to, uint256 tokenId, uint256 amount) external auth {
        _mint(to, tokenId, amount);
    }

    /// @notice Authorized burn (for lazy sync by attestor/keeper)
    function burn(address from, uint256 tokenId, uint256 amount) external auth {
        _burn(from, tokenId, amount);
    }

    /// @notice Batch mint shares
    function mintMany(address[] calldata toList, uint256 tokenId, uint256[] calldata amountList) external auth {
        if (toList.length != amountList.length) revert Error.Compact__ArrayLengthMismatch();
        for (uint256 i; i < toList.length; ++i) {
            if (amountList[i] != 0) {
                _mint(toList[i], tokenId, amountList[i]);
            }
        }
    }

    /// @notice Batch burn shares (for lazy sync)
    function burnMany(address[] calldata fromList, uint256 tokenId, uint256[] calldata amountList) external auth {
        if (fromList.length != amountList.length) revert Error.Compact__ArrayLengthMismatch();
        for (uint256 i; i < fromList.length; ++i) {
            if (amountList[i] != 0) {
                _burn(fromList[i], tokenId, amountList[i]);
            }
        }
    }

    // ============ ERC6909 Metadata ============

    function name(uint256) public pure override returns (string memory) {
        return "Puppet Share";
    }

    function symbol(uint256) public pure override returns (string memory) {
        return "pSHARE";
    }

    function decimals(uint256) public pure override returns (uint8) {
        return 18;
    }

    function tokenURI(uint256) public pure override returns (string memory) {
        return "";
    }

    // ============ ERC165 ============

    /// @dev ERC165: 0x01ffc9a7, ERC6909: 0x0f632fb3
    function supportsInterface(bytes4 interfaceId) public pure override(ERC6909, CoreContract) returns (bool result) {
        assembly {
            let s := shr(224, interfaceId)
            result := or(eq(s, 0x01ffc9a7), eq(s, 0x0f632fb3))
        }
    }

    function _setConfig(bytes memory) internal override {}
}
