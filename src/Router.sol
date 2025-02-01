// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Multicall} from "@openzeppelin/contracts/utils/Multicall.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";

import {CoreContract} from "./utils/CoreContract.sol";
import {Access} from "./utils/auth/Access.sol";
import {IAuthority} from "./utils/interfaces/IAuthority.sol";
import {FeeMarketplace} from "./tokenomics/FeeMarketplace.sol";


contract Router is UUPSUpgradeable, ReentrancyGuardTransient, Multicall {
    IAuthority public authority;
    FeeMarketplace marketplace;

    constructor(IAuthority _authority, FeeMarketplace _marketplace) {
        authority = _authority;
        marketplace = _marketplace;
    }

    /// @notice Exchange protocol tokens for protocol-collected fees at governance-set rates
    /// @dev Implements a fixed-rate redemption system with:
    /// @param token The token to exchange
    /// @param receiver The address to receive the exchanged tokens
    /// @param amount The amount of tokens to exchange
    function acceptOffer(IERC20 token, address receiver, uint amount) external nonReentrant {
        marketplace.acceptOffer(token, receiver, amount);
    }

    // internal

    function _authorizeUpgrade(
        address
    ) internal override {
        // if (msg.sender != address(authority)) {
        //     revert("Unauthorized");
        // }
    }
}
