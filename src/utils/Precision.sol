// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

library Precision {
    uint internal constant BASIS_POINT_DIVISOR = 10000;
    uint public constant FLOAT_PRECISION = 10 ** 30;

    function diff(uint a, uint b) internal pure returns (uint) {
        return a > b ? a - b : b - a;
    }

    function applyBasisPoints(uint bps, uint value) internal pure returns (uint) {
        return Math.mulDiv(value, bps, BASIS_POINT_DIVISOR);
    }

    function toBasisPoints(uint value, uint divisor) internal pure returns (uint) {
        return Math.mulDiv(value, BASIS_POINT_DIVISOR, divisor);
    }

    function applyFactor(uint factor, uint value) internal pure returns (uint) {
        return Math.mulDiv(value, factor, FLOAT_PRECISION);
    }

    function toFactor(uint value, uint divisor) internal pure returns (uint) {
        return Math.mulDiv(value, FLOAT_PRECISION, divisor);
    }
}
