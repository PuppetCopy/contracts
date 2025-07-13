// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Error} from "../utils/Error.sol";
import {IWNT} from "./interfaces/IWNT.sol";

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
        validateDestination(receiver);

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
        validateDestination(receiver);

        wnt.deposit{value: amount}();

        transferWithFallback(gasLimit, holdingAddress, wnt, receiver, amount);
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
        validateDestination(receiver);

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
    function transferWithFallback(
        uint gasLimit,
        address holdingAddress,
        IERC20 token,
        address receiver,
        uint amount
    ) internal {
        if (amount == 0) return;
        validateDestination(receiver);

        // Try transfer to primary receiver using improved internal method
        if (_callOptionalReturnBool(gasLimit, token, abi.encodeCall(token.transfer, (receiver, amount)))) {
            return;
        }

        require(holdingAddress != address(0), Error.TransferUtils__EmptyHoldingAddress());

        // Fallback: transfer to holding address to avoid gaming through reverting
        require(
            _callOptionalReturnBool(gasLimit, token, abi.encodeCall(token.transfer, (holdingAddress, amount))),
            Error.TransferUtils__TokenTransferError(token, holdingAddress, amount)
        );
    }

    /**
     * @dev Transfer `value` amount of `token` from the calling contract to `to`. If `token` returns no value,
     * non-reverting calls are assumed to be successful. Reverts on transfer failure.
     */
    function transferStrictly(uint gasLimit, IERC20 token, address to, uint value) internal {
        require(
            _callOptionalReturnBool(gasLimit, token, abi.encodeCall(token.transfer, (to, value))),
            Error.TransferUtils__TokenTransferError(token, to, value)
        );
    }

    /**
     * @dev Transfer `value` amount of `token` from `from` to `to`, spending the approval given by `from` to the
     * calling contract. If `token` returns no value, non-reverting calls are assumed to be successful.
     */
    function transferStrictlyFrom(uint gasLimit, IERC20 token, address from, address to, uint value) internal {
        require(
            _callOptionalReturnBool(gasLimit, token, abi.encodeCall(token.transferFrom, (from, to, value))),
            Error.TransferUtils__TokenTransferFromError(token, from, to, value)
        );
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
                if (isContract(address(token)) == false) {
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

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     *
     * This is a variant of {_callOptionalReturnBool} that reverts if call fails to meet the requirements.
     */
    function _callOptionalReturn(uint gasLimit, IERC20 token, bytes memory data) private {
        uint returnSize;
        uint returnValue;
        assembly ("memory-safe") {
            let success := call(gasLimit, token, 0, add(data, 0x20), mload(data), 0, 0x20)
            // bubble errors
            if iszero(success) {
                let ptr := mload(0x40)
                returndatacopy(ptr, 0, returndatasize())
                revert(ptr, returndatasize())
            }
            returnSize := returndatasize()
            returnValue := mload(0)
        }

        if (returnSize == 0 ? address(token).code.length == 0 : returnValue != 1) {
            revert Error.TransferUtils__SafeERC20FailedOperation(token);
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     *
     * This is a variant of {_callOptionalReturn} that silently catches all reverts and returns a bool instead.
     */
    function _callOptionalReturnBool(uint gasLimit, IERC20 token, bytes memory data) private returns (bool) {
        bool success;
        uint returnSize;
        uint returnValue;
        assembly ("memory-safe") {
            success := call(gasLimit, token, 0, add(data, 0x20), mload(data), 0, 0x20)
            returnSize := returndatasize()
            returnValue := mload(0)
        }
        return success && (returnSize == 0 ? address(token).code.length > 0 : returnValue == 1);
    }

    // validateDestination
    /**
     * @dev Validates that the destination address is not the zero address.
     * @param receiver The address to validate.
     */
    function validateDestination(
        address receiver
    ) internal pure {
        require(receiver != address(0), Error.TransferUtils__InvalidReceiver());
    }

    /**
     * @dev Checks if the given address is a contract.
     * @param account The address to check.
     * @return True if the address is a contract, false otherwise.
     */
    function isContract(
        address account
    ) internal view returns (bool) {
        uint size;
        assembly ("memory-safe") {
            size := extcodesize(account)
        }
        return size > 0;
    }
}
