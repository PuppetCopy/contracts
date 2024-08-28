// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ExternalCallUtils} from "../utils/ExternalCallUtils.sol";
import {Permission} from "./../utils/access/Permission.sol";
import {IAuthority} from "./../utils/interfaces/IAuthority.sol";

/**
 * @title Router
 * @dev Users will approve this router for token spenditures
 */
contract Router is Permission {
    uint transferGasLimit;

    constructor(IAuthority _authority, uint _trasnferGasLimit) Permission(_authority) {
        authority = _authority;
        transferGasLimit = _trasnferGasLimit;
    }

    /**
     * @dev low level call to an ERC20 contract, return raw data to be handled by authorised contract
     * @param token the token to transfer
     * @param from the account to transfer from
     * @param to the account to transfer to
     * @param amount the amount to transfer
     */
    function transfer(IERC20 token, address from, address to, uint amount) external auth {
        ExternalCallUtils.callTarget(
            transferGasLimit, address(token), abi.encodeCall(token.transferFrom, (from, to, amount))
        );
    }

    function setTransferGasLimit(uint _trasnferGasLimit) external auth {
        transferGasLimit = _trasnferGasLimit;
    }
}
