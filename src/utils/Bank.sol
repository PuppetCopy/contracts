// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import {Auth, Authority} from "@solmate/contracts/auth/Auth.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IWNT} from "./interfaces/IWNT.sol";

import {TransferUtils} from "./TransferUtils.sol";
import {StoreController} from "./StoreController.sol";

// @title Bank
// @dev Contract to handle storing and transferring of tokens
abstract contract Bank is StoreController {
    struct Config {
        IWNT wnt;
        address holdingAddress;
        uint gasLimit;
    }

    mapping(IERC20 => uint) public tokenBalances;

    Config public config;

    constructor(Authority _authority, Config memory _config, address _initSetter) StoreController(_authority, _initSetter) {
        _setConfig(_config);
    }

    receive() external payable {
        if (msg.sender != address(config.wnt)) {
            revert Bank__InvalidNativeTokenSender(msg.sender);
        }
    }

    // @dev transfer native tokens from this contract to a receiver
    // @param token the token to transfer
    // @param amount the amount to transfer
    // @param receiver the address to transfer to
    // @param shouldUnwrapNativeToken whether to unwrap the wrapped native token
    // before transferring
    function transferOutNativeToken(address receiver, uint amount) external requiresAuth {
        if (receiver == address(this)) {
            revert Bank__SelfTransferNotSupported(receiver);
        }

        TransferUtils.withdrawAndSendNativeToken(config.wnt, config.gasLimit, config.holdingAddress, receiver, amount);
        tokenBalances[config.wnt] = config.wnt.balanceOf(address(this));
    }

    // @dev transfer tokens from this contract to a receiver
    //
    // @param token the token to transfer
    // @param amount the amount to transfer
    // @param receiver the address to transfer to
    function transferOut(IERC20 token, address receiver, uint amount) external requiresAuth {
        if (receiver == address(this)) {
            revert Bank__SelfTransferNotSupported(receiver);
        }

        TransferUtils.transfer(config.gasLimit, config.holdingAddress, token, receiver, amount);

        tokenBalances[token] = token.balanceOf(address(this));
    }

    // @dev records a token transfer into the contract
    // @param token the token to record the transfer for
    // @return the amount of tokens transferred in
    function recordTransferIn(IERC20 token) external requiresAuth returns (uint) {
        uint prevBalance = tokenBalances[token];
        uint nextBalance = token.balanceOf(address(this));
        tokenBalances[token] = nextBalance;

        return nextBalance - prevBalance;
    }

    // @dev this can be used to update the tokenBalances in case of token burns
    // or similar balance changes
    // the prevBalance is not validated to be more than the nextBalance as this
    // could allow someone to block this call by transferring into the contract
    // @param token the token to record the burn for
    // @return the new balance
    function syncTokenBalance(IERC20 token) external requiresAuth returns (uint) {
        uint nextBalance = token.balanceOf(address(this));
        tokenBalances[token] = nextBalance;
        return nextBalance;
    }

    function _setConfig(Config memory _config) internal virtual {
        config = _config;
    }

    error Bank__InvalidNativeTokenSender(address sender);
    error Bank__SelfTransferNotSupported(address receiver);
}
