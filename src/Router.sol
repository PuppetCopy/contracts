// // SPDX-License-Identifier: BUSL-1.1
// pragma solidity 0.8.28;

// import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
// import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import {Multicall} from "@openzeppelin/contracts/utils/Multicall.sol";

// import {BuyAndBurn} from "./tokenomics/BuyAndBurn.sol";
// import {CoreContract} from "./utils/CoreContract.sol";
// import {ReentrancyGuardTransient} from "./utils/ReentrancyGuardTransient.sol";
// import {Access} from "./utils/auth/Access.sol";
// import {IAuthority} from "./utils/interfaces/IAuthority.sol";

// contract Router is UUPSUpgradeable, ReentrancyGuardTransient, Multicall {
//     IAuthority public authority;
//     BuyAndBurn bab;

//     constructor(IAuthority _authority, BuyAndBurn _bab) {
//         authority = _authority;
//         bab = _bab;
//     }

//     /// @notice Executes the buyback of revenue tokens using the protocol's accumulated fees.
//     /// @param token The address of the revenue token to be bought back.
//     /// @param receiver The address that will receive the revenue token.
//     /// @param amount The amount of revenue tokens to be bought back.
//     function buyAndBurn(IERC20 token, address receiver, uint amount) external nonReentrant {
//         bab.buyAndBurn(token, msg.sender, receiver, amount);
//     }

//     // internal

//     function _authorizeUpgrade(
//         address
//     ) internal override {
//         // if (msg.sender != address(authority)) {
//         //     revert("Unauthorized");
//         // }
//     }
// }
