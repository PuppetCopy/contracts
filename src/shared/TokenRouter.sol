// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {CallUtils} from "../utils/CallUtils.sol";
import {Access} from "./../utils/auth/Access.sol";
import {IAuthority} from "./../utils/interfaces/IAuthority.sol";

/**
 * @title TokenRouter
 * @dev Central token router and spending approval for transferring tokens
 */
contract TokenRouter is Access {
    uint transferGasLimit;

    constructor(IAuthority _authority, uint _initialTransferGasLimit) Access(_authority) {
        authority = _authority;
        transferGasLimit = _initialTransferGasLimit;
    }

    /**
     * @dev low level call to an ERC20 contract, return raw data to be handled by authorised contract
     * @param token the token to transfer
     * @param from the account to transfer from
     * @param to the account to transfer to
     * @param amount the amount to transfer
     */
    function transfer(IERC20 token, address from, address to, uint amount) external auth {
        CallUtils.callTarget(transferGasLimit, address(token), abi.encodeCall(token.transferFrom, (from, to, amount)));
    }

    function setTransferGasLimit(
        uint _trasnferGasLimit
    ) external auth {
        transferGasLimit = _trasnferGasLimit;
    }
}
