// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/// @title Math library
/// @dev Derived from OpenZeppelin's Math library. To avoid conflicts with OpenZeppelin's Math,
/// it has been renamed to `M` here. Import it using the following statement:
///      import {M as Math} from "path/to/Math.sol";
library Precision {
    uint internal constant BASIS_POINT_DIVISOR = 10000;
    uint public constant FLOAT_PRECISION = 10 ** 30;

    /**
     * @dev Calculates the absolute difference between two numbers.
     *
     * @param a the first number
     * @param b the second number
     * @return the absolute difference between the two numbers
     */
    function diff(uint a, uint b) internal pure returns (uint) {
        return a > b ? a - b : b - a;
    }

    function applyBasisPoints(uint value, uint divisor) internal pure returns (uint) {
        return Math.mulDiv(value, divisor, BASIS_POINT_DIVISOR);
    }

    function toBasisPoints(uint value, uint total) internal pure returns (uint) {
        return Math.mulDiv(value, BASIS_POINT_DIVISOR, total);
    }

    /**
     * Applies the given factor to the given value and returns the result.
     *
     * @param value The value to apply the factor to.
     * @param factor The factor to apply.
     * @return The result of applying the factor to the value.
     */
    function applyFactor(uint value, uint factor) internal pure returns (uint) {
        return Math.mulDiv(value, factor, FLOAT_PRECISION);
    }

    function toFactor(uint value, uint divisor) internal pure returns (uint) {
        return Math.mulDiv(value, FLOAT_PRECISION, divisor);
    }
}
