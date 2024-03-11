// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Math as _math} from "@openzeppelin/contracts/utils/math/Math.sol";

/// @title Math library
/// @dev Derived from OpenZeppelin's Math library. To avoid conflicts with OpenZeppelin's Math,
/// it has been renamed to `M` here. Import it using the following statement:
///      import {M as Math} from "path/to/Math.sol";
library Math {
    uint internal constant BASIS_POINT_DIVISOR = 10000;

    enum Rounding {
        Up,
        Down
    }

    function max(uint a, uint b) internal pure returns (uint) {
        return a > b ? a : b;
    }

    function min(uint a, uint b) internal pure returns (uint) {
        return a < b ? a : b;
    }

    /// @notice Calculate `a / b` with rounding up
    function ceilDiv(uint a, uint b) internal pure returns (uint) {
        // Guarantee the same behavior as in a regular Solidity division
        if (b == 0) return a / b;

        // prettier-ignore
        unchecked {
            return a == 0 ? 0 : (a - 1) / b + 1;
        }
    }

    /// @notice Calculate `x * y / denominator` with rounding down
    function mulDiv(uint x, uint y, uint denominator) internal pure returns (uint) {
        return _math.mulDiv(x, y, denominator);
    }

    /// @notice Calculate `x * y / denominator` with rounding up
    function mulDivUp(uint x, uint y, uint denominator) internal pure returns (uint) {
        return _math.mulDiv(x, y, denominator, _math.Rounding.Ceil);
    }

    function mulDiv(uint x, uint y, uint denominator, Rounding rounding) internal pure returns (uint) {
        return _math.mulDiv(x, y, denominator, rounding == Rounding.Up ? _math.Rounding.Ceil : _math.Rounding.Floor);
    }

    /// @notice Calculate `x * y / denominator` with rounding down and up
    /// @return result Result with rounding down
    /// @return resultUp Result with rounding up
    function mulDiv2(uint x, uint y, uint denominator) internal pure returns (uint result, uint resultUp) {
        result = _math.mulDiv(x, y, denominator);
        resultUp = result;
        if (mulmod(x, y, denominator) > 0) resultUp += 1;
    }
}
