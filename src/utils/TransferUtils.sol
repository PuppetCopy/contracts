// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Error} from "../utils/Error.sol";
import {IWNT} from "./interfaces/IWNT.sol";

/**
 * @title TransferUtils
 * @dev Library for secure token transfers with gas limiting and fallback mechanisms.
 * Provides functions for both ERC20 tokens and native token operations with protection
 * against gas griefing attacks and fallback handling for blacklisted receivers.
 */
library TransferUtils {
    /**
     * @dev Sends native token to receiver with fallback to wrapped token transfer.
     * First attempts direct native token transfer, if that fails, wraps the token
     * and sends wrapped tokens using the fallback mechanism.
     *
     * @param wnt The wrapped native token contract
     * @param holdingAddress Fallback address if receiver transfer fails
     * @param gasLimit Maximum gas for the native token transfer
     * @param receiver Recipient of the native/wrapped token transfer
     * @param amount Amount of native token to send
     */
    function sendNativeToken(IWNT wnt, address holdingAddress, uint gasLimit, address receiver, uint amount) internal {
        if (amount == 0) return;
        require(receiver != address(0), Error.TransferUtils__InvalidReceiver());

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
     * @dev Deposits native token and transfers wrapped tokens with fallback protection.
     * Wraps the native token and uses the secure transfer mechanism with fallback
     * to prevent gaming through reverting transfers.
     *
     * @param wnt The wrapped native token contract
     * @param holdingAddress Fallback address for failed transfers (prevents gaming)
     * @param gasLimit Maximum gas for token transfers
     * @param receiver Primary recipient of wrapped tokens
     * @param amount Amount to deposit and transfer
     */
    function depositAndSendWnt(
        IWNT wnt,
        address holdingAddress,
        uint gasLimit,
        address receiver,
        uint amount
    ) internal {
        if (amount == 0) return;
        require(receiver != address(0), Error.TransferUtils__InvalidReceiver());

        wnt.deposit{value: amount}();

        transferWithFallback(gasLimit, holdingAddress, wnt, receiver, amount);
    }

    /**
     * @dev Withdraws wrapped tokens and sends native tokens with fallback protection.
     * Unwraps tokens and attempts native transfer. If native transfer fails,
     * re-wraps and sends wrapped tokens to prevent gaming through reverting.
     * Gas limit prevents griefing attacks.
     *
     * @param wnt The wrapped native token contract
     * @param gasLimit Maximum gas for native token transfer (prevents griefing)
     * @param holdingAddress Fallback address for failed transfers (prevents gaming)
     * @param receiver Primary recipient of native tokens
     * @param amount Amount to withdraw and send
     */
    function withdrawAndSendNativeToken(
        IWNT wnt,
        uint gasLimit,
        address holdingAddress,
        address receiver,
        uint amount
    ) internal {
        if (amount == 0) return;
        require(receiver != address(0), Error.TransferUtils__InvalidReceiver());

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
     * @dev Securely transfers ERC20 tokens with fallback mechanism.
     * Attempts transfer to primary receiver first. If that fails (e.g. blacklisting),
     * transfers to holding address to prevent gaming through reverting transactions.
     * Gas limiting prevents griefing attacks.
     *
     * @param gasLimit Maximum gas for token transfers (prevents griefing)
     * @param holdingAddress Fallback address for failed transfers (prevents gaming)
     * @param token The ERC20 token contract
     * @param receiver Primary recipient of tokens
     * @param amount Amount of tokens to transfer
     */
    function transferWithFallback(
        uint gasLimit,
        address holdingAddress,
        IERC20 token,
        address receiver,
        uint amount
    ) internal {
        if (amount == 0) return;
        require(receiver != address(0), Error.TransferUtils__InvalidReceiver());

        require(gasLimit > 0, Error.TransferUtils__EmptyTokenTransferGasLimit(token));

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
     * @dev Strictly transfers ERC20 tokens with gas limiting.
     * Handles both returning and non-returning ERC20 tokens correctly.
     * Reverts if transfer fails - no fallback mechanism.
     *
     * @param gasLimit Maximum gas for the transfer
     * @param token The ERC20 token contract
     * @param to Recipient address
     * @param value Amount to transfer
     */
    function transferStrictly(uint gasLimit, IERC20 token, address to, uint value) internal {
        require(
            _callOptionalReturnBool(gasLimit, token, abi.encodeCall(token.transfer, (to, value))),
            Error.TransferUtils__TokenTransferError(token, to, value)
        );
    }

    /**
     * @dev Strictly transfers ERC20 tokens using transferFrom with gas limiting.
     * Handles both returning and non-returning ERC20 tokens correctly.
     * Reverts if transfer fails - no fallback mechanism.
     *
     * @param gasLimit Maximum gas for the transfer
     * @param token The ERC20 token contract
     * @param from Address to transfer from (must have approved this contract)
     * @param to Recipient address
     * @param value Amount to transfer
     */
    function transferStrictlyFrom(uint gasLimit, IERC20 token, address from, address to, uint value) internal {
        require(
            _callOptionalReturnBool(gasLimit, token, abi.encodeCall(token.transferFrom, (from, to, value))),
            Error.TransferUtils__TokenTransferFromError(token, from, to, value)
        );
    }

    /**
     * @dev Internal function for secure ERC20 calls that reverts on failure.
     * Handles both returning and non-returning ERC20 tokens. Based on OpenZeppelin's SafeERC20.
     * Reverts if the call fails or returns false.
     *
     * @param gasLimit Maximum gas for the call
     * @param token The ERC20 token contract
     * @param data The encoded call data (e.g., transfer, transferFrom)
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
     * @dev Internal function for secure ERC20 calls that returns success status.
     * Handles both returning and non-returning ERC20 tokens. Based on OpenZeppelin's SafeERC20.
     * Returns false if the call fails or returns false, true otherwise.
     *
     * @param gasLimit Maximum gas for the call
     * @param token The ERC20 token contract
     * @param data The encoded call data (e.g., transfer, transferFrom)
     * @return success True if call succeeded and returned true (or no data), false otherwise
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
}
