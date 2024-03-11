// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {WNT} from "./WNT.sol";
import {TransferUtils} from "./TransferUtils.sol";
import {Router} from "./Router.sol";
import {Multicall} from "@openzeppelin/contracts/utils/Multicall.sol";

abstract contract MulticallRouter is ReentrancyGuard, Router, Multicall {
    WNT public immutable wnt;
    Router public immutable router;

    uint nativeTokenGasLimit = 50_000;
    uint tokenGasLimit = 200_000;
    address holdingAddress;

    constructor(Authority _authority, WNT _wnt, Router _router, address _holdingAddress) Router(_authority) {
        wnt = _wnt;
        router = _router;
        holdingAddress = _holdingAddress;
    }

    /**
     * @dev Receives and executes a batch of function calls on this contract.
     * @custom:oz-upgrades-unsafe-allow-reachable delegatecall
     */
    function payableMulticall(bytes[] calldata data) external payable virtual returns (bytes[] memory results) {
        return this.multicall(data);
    }

    // @dev Wraps the specified amount of native tokens into WNT then sends the WNT to the specified address
    function sendWnt(address receiver, uint amount) external payable nonReentrant {
        TransferUtils.depositAndSendWrappedNativeToken(wnt, holdingAddress, tokenGasLimit, receiver, amount);
    }

    // @dev Sends native token given amount and address
    function sendNativeToken(address receiver, uint amount) external payable nonReentrant {
        TransferUtils.sendNativeToken(wnt, holdingAddress, nativeTokenGasLimit, receiver, amount);
    }

    // @dev Sends the given amount of tokens to the given address
    function sendTokens(IERC20 token, address receiver, uint amount) external payable nonReentrant {
        router.pluginTransfer(token, msg.sender, receiver, amount);
    }

    function setNativeTokenGasLimit(uint _nativeTokenGasLimit) external requiresAuth {
        nativeTokenGasLimit = _nativeTokenGasLimit;
    }

    function setHoldingAddress(address _holdingAddress) external requiresAuth {
        holdingAddress = _holdingAddress;
    }
}
