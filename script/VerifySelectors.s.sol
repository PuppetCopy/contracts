// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.29;

import {Script} from "forge-std/src/Script.sol";
import {console} from "forge-std/src/console.sol";

import {IOrderCallbackReceiver} from "@gmx/contracts/callback/IOrderCallbackReceiver.sol";
import {IGasFeeCallbackReceiver} from "@gmx/contracts/callback/IGasFeeCallbackReceiver.sol";
import {IGmxOrderCallbackReceiver} from "src/position/interface/IGmxOrderCallbackReceiver.sol";

/**
 * @title VerifySelectors
 * @notice Standalone script to verify selector compatibility between GMX interfaces and SequencerRouter
 * @dev This ensures that SequencerRouter correctly implements the required callback interfaces
 *      GMX uses function selectors to route callbacks - any mismatch will cause callbacks to fail
 */
contract VerifySelectors is Script {
    function run() public view {
        verifySelectorsMatch();
    }

    /**
     * @notice Verifies that SequencerRouter selectors match GMX callback interface selectors
     * @dev This is critical for GMX callbacks to work properly
     */
    function verifySelectorsMatch() public pure {
        console.log("\n=== Verifying Selector Compatibility ===\n");

        // Get expected selectors from GMX interfaces
        bytes4 expectedAfterOrderExecution = IOrderCallbackReceiver.afterOrderExecution.selector;
        bytes4 expectedAfterOrderCancellation = IOrderCallbackReceiver.afterOrderCancellation.selector;
        bytes4 expectedAfterOrderFrozen = IOrderCallbackReceiver.afterOrderFrozen.selector;
        bytes4 expectedRefundExecutionFee = IGasFeeCallbackReceiver.refundExecutionFee.selector;

        // Get actual selectors from our interface
        bytes4 actualAfterOrderExecution = IGmxOrderCallbackReceiver.afterOrderExecution.selector;
        bytes4 actualAfterOrderCancellation = IGmxOrderCallbackReceiver.afterOrderCancellation.selector;
        bytes4 actualAfterOrderFrozen = IGmxOrderCallbackReceiver.afterOrderFrozen.selector;
        bytes4 actualRefundExecutionFee = IGmxOrderCallbackReceiver.refundExecutionFee.selector;

        console.log("afterOrderExecution:");
        console.log("  Expected (GMX): %s", vm.toString(expectedAfterOrderExecution));
        console.log("  Actual (Ours):  %s", vm.toString(actualAfterOrderExecution));

        console.log("afterOrderCancellation:");
        console.log("  Expected (GMX): %s", vm.toString(expectedAfterOrderCancellation));
        console.log("  Actual (Ours):  %s", vm.toString(actualAfterOrderCancellation));

        console.log("afterOrderFrozen:");
        console.log("  Expected (GMX): %s", vm.toString(expectedAfterOrderFrozen));
        console.log("  Actual (Ours):  %s", vm.toString(actualAfterOrderFrozen));

        console.log("refundExecutionFee:");
        console.log("  Expected (GMX): %s", vm.toString(expectedRefundExecutionFee));
        console.log("  Actual (Ours):  %s", vm.toString(actualRefundExecutionFee));

        require(
            expectedAfterOrderExecution == actualAfterOrderExecution,
            "afterOrderExecution selector mismatch"
        );
        require(
            expectedAfterOrderCancellation == actualAfterOrderCancellation,
            "afterOrderCancellation selector mismatch"
        );
        require(
            expectedAfterOrderFrozen == actualAfterOrderFrozen,
            "afterOrderFrozen selector mismatch"
        );
        require(
            expectedRefundExecutionFee == actualRefundExecutionFee,
            "refundExecutionFee selector mismatch"
        );

        console.log("\nAll selectors match correctly!");
    }
}
