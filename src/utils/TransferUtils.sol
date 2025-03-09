// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Error} from "../shared/Error.sol";
import {ErrorUtils} from "./ErrorUtils.sol";
import {CallUtils} from "./CallUtils.sol";
import {IWNT} from "./interfaces/IWNT.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title TransferUtils
 * @dev Library for token functions, helps with transferring of tokens and
 * native token functions
 */
library TransferUtils {
    /**
     * @dev Deposits the specified amount of native token and sends the
     * corresponding amount of wrapped native token to the specified receiver address.
     *
     * @param wnt the address of the wrapped native token contract
     * @param holdingAddress the address of the holding account where the native token is held
     * @param gasLimit the maximum amount of gas that the native token transfer can consume
     * @param receiver the address of the recipient of the wrapped native token transfer
     * @param amount the amount of native token to deposit and the amount of wrapped native token to send
     */
    function sendNativeToken(IWNT wnt, address holdingAddress, uint gasLimit, address receiver, uint amount) internal {
        if (amount == 0) return;
        CallUtils.validateDestination(receiver);

        bool success;
        // use an assembly call to avoid loading large data into memory
        // input mem[in…(in+insize)]
        // output area mem[out…(out+outsize))]
        assembly {
            success :=
                call(
                    gasLimit, // gas limit
                    receiver, // receiver
                    amount, // value
                    0, // in
                    0, // insize
                    0, // out
                    0 // outsize
                )
        }

        if (success) return;

        // if the transfer failed, re-wrap the token and send it to the receiver
        depositAndSendWnt(wnt, holdingAddress, gasLimit, receiver, amount);
    }

    /**
     * Deposits the specified amount of native token and sends the specified
     * amount of wrapped native token to the specified receiver address.
     *
     * @param wnt the address of the wrapped native token contract
     * @param holdingAddress in case transfers to the receiver fail due to blacklisting or other reasons
     *  send the tokens to a holding address to avoid possible gaming through reverting
     * @param gasLimit the maximum amount of gas that the native token transfer can consume
     * @param receiver the address of the recipient of the wrapped native token transfer
     * @param amount the amount of native token to deposit and the amount of wrapped native token to send
     */
    function depositAndSendWnt(
        IWNT wnt,
        address holdingAddress,
        uint gasLimit,
        address receiver,
        uint amount
    ) internal {
        if (amount == 0) return;
        CallUtils.validateDestination(receiver);

        wnt.deposit{value: amount}();

        transfer(gasLimit, holdingAddress, wnt, receiver, amount);
    }

    /**
     * @dev Withdraws the specified amount of wrapped native token and sends the
     * corresponding amount of native token to the specified receiver address.
     *
     * limit the amount of gas forwarded so that a user cannot intentionally
     * construct a token call that would consume all gas and prevent necessary
     * actions like request cancellation from being executed
     *
     * @param wnt the address of the WNT contract to withdraw the wrapped native token from
     * * @param gasLimit the maximum amount of gas that the native token transfer can consume
     * @param holdingAddress in case transfers to the receiver fail due to blacklisting or other reasons
     *  send the tokens to a holding address to avoid possible gaming through reverting
     * @param receiver the address of the recipient of the native token transfer
     * @param amount the amount of wrapped native token to withdraw and the amount of native token to send
     */
    function withdrawAndSendNativeToken(
        IWNT wnt,
        uint gasLimit,
        address holdingAddress,
        address receiver,
        uint amount
    ) internal {
        if (amount == 0) return;
        CallUtils.validateDestination(receiver);

        wnt.withdraw(amount);

        bool success;
        // use an assembly call to avoid loading large data into memory
        // input mem[in…(in+insize)]
        // output area mem[out…(out+outsize))]
        assembly {
            success :=
                call(
                    gasLimit, // gas limit
                    receiver, // receiver
                    amount, // value
                    0, // in
                    0, // insize
                    0, // out
                    0 // outsize
                )
        }

        if (success) return;

        // if the transfer failed, re-wrap the token and send it to the receiver
        depositAndSendWnt(wnt, holdingAddress, gasLimit, receiver, amount);
    }

    /**
     * @dev Transfers the specified amount of `token` from the caller to `receiver`.
     * limit the amount of gas forwarded so that a user cannot intentionally
     * construct a token call that would consume all gas and prevent necessary
     * actions like request cancellation from being executed
     *
     * @param gasLimit The maximum amount of gas that the token transfer can consume.
     * @param holdingAddress in case transfers to the receiver fail due to blacklisting or other reasons
     *  send the tokens to a holding address to avoid possible gaming through reverting
     * @param token The address of the ERC20 token that is being transferred.
     * @param receiver The address of the recipient of the `token` transfer.
     * @param amount The amount of `token` to transfer.
     */
    function transfer(uint gasLimit, address holdingAddress, IERC20 token, address receiver, uint amount) internal {
        if (amount == 0) return;
        CallUtils.validateDestination(receiver);

        require(gasLimit > 0, Error.TransferUtils__EmptyTokenTranferGasLimit(token));

        (bool success0, /* bytes memory returndata */ ) =
            nonRevertingTransferWithGasLimit(token, receiver, amount, gasLimit);

        if (success0) return;

        require(holdingAddress != address(0), Error.TransferUtils__EmptyHoldingAddress());

        // in case transfers to the receiver fail due to blacklisting or other reasons
        // send the tokens to a holding address to avoid possible gaming through reverting
        // transfers
        (bool success1, bytes memory returndata) =
            nonRevertingTransferWithGasLimit(token, holdingAddress, amount, gasLimit);

        if (success1) return;

        (string memory reason, /* bool hasRevertMessage */ ) = ErrorUtils.getRevertMessage(returndata);
        emit Error.TransferUtils__TokenTransferReverted(reason, returndata);

        // throw custom errors to prevent spoofing of errors
        // this is necessary because contracts like DepositHandler, WithdrawalHandler, OrderHandler
        // do not cancel requests for specific errors
        revert Error.TransferUtils__TokenTransferError(token, receiver, amount);
    }

    /**
     * @dev Transfers the specified amount of ERC20 token to the specified receiver
     * address, with a gas limit to prevent the transfer from consuming all available gas.
     * adapted from
     * https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/utils/SafeERC20.sol
     *
     * @param token the ERC20 contract to transfer the tokens from
     * @param to the address of the recipient of the token transfer
     * @param amount the amount of tokens to transfer
     * @param gasLimit the maximum amount of gas that the token transfer can consume
     * @return a tuple containing a boolean indicating the success or failure of the
     * token transfer, and a bytes value containing the return data from the token transfer
     */
    function nonRevertingTransferWithGasLimit(
        IERC20 token,
        address to,
        uint amount,
        uint gasLimit
    ) internal returns (bool, bytes memory) {
        bytes memory data = abi.encodeWithSelector(token.transfer.selector, to, amount);
        (bool success, bytes memory returndata) = address(token).call{gas: gasLimit}(data);

        if (success) {
            if (returndata.length == 0) {
                // only check isContract if the call was successful and the return data is empty
                // otherwise we already know that it was a contract
                if (CallUtils.isContract(address(token)) == false) {
                    return (false, "Call to non-contract");
                }
            }

            // some tokens do not revert on a failed transfer, they will return a boolean instead
            // validate that the returned boolean is true, otherwise indicate that the token transfer failed
            if (returndata.length > 0 && !abi.decode(returndata, (bool))) {
                return (false, returndata);
            }

            // transfers on some tokens do not return a boolean value, they will just revert if a transfer fails
            // for these tokens, if success is true then the transfer should have completed
            return (true, returndata);
        }

        return (false, returndata);
    }
}
