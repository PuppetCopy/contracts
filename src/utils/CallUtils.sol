// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Error} from "../shared/Error.sol";

/**
 * @title CallUtils
 * @dev Various utility functions for external calls, including checks for contract existence and call success
 * native token functions
 */
library CallUtils {
    /**
     * @dev Checks if the specified address is a contract.
     *
     * @param account The address to check.
     * @return a boolean indicating whether the specified address is a contract.
     */
    function isContract(
        address account
    ) internal view returns (bool) {
        // According to EIP-1052, 0x0 is the value returned for not-yet created accounts
        // and 0xc5d246... is returned for accounts without code, i.e., `keccak256('')`
        uint size;
        // inline assembly is used to access the EVM's `extcodesize` operation
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    /**
     * @dev Validates that the specified destination address is not the zero address.
     *
     * @param destination The address to validate.
     */
    function validateDestination(
        address destination
    ) internal pure {
        require(destination != address(0), Error.CallUtils__EmptyReceiver());
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and reverts if the target
     * was not a contract or bubbling up the revert reason (falling back to {FailedInnerCall}) in case of an
     * unsuccessful call.
     */
    function callTarget(uint gasLimit, address target, bytes memory data) internal returns (bytes memory) {
        (bool success, bytes memory returndata) = target.call{gas: gasLimit}(data);

        require(
            returndata.length != 0 && abi.decode(returndata, (bool)),
            Error.CallUtils__SafeERC20FailedOperation(target)
        );

        if (success) {
            require(returndata.length > 0 && target.code.length > 0, Error.CallUtils__AddressEmptyCode(target));

            return returndata;
        } else {
            _revert(returndata);
        }
    }

    /**
     * @dev Reverts with returndata if present. Otherwise reverts with {FailedInnerCall}.
     */
    function _revert(
        bytes memory returndata
    ) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert Error.CallUtils__FailedInnerCall();
        }
    }
}
