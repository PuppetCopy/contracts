// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Calc} from "./../../utils/Calc.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

library PositionUtils {
    function getPlatformMatchingFee(uint matchingFee, uint sizeDelta) internal pure returns (uint) {
        uint feeAmount = sizeDelta * matchingFee / Calc.BASIS_POINT_DIVISOR;

        return feeAmount;
    }

    function getPlatformProfitFee(uint feeRate, uint profit) internal pure returns (uint) {
        return profit * feeRate / Calc.BASIS_POINT_DIVISOR;
    }

    function getPlatformTraderProfitFeeCutoff(uint cutoffRate, uint profit) internal pure returns (uint) {
        return profit * cutoffRate / Calc.BASIS_POINT_DIVISOR;
    }

    function getPlatformProfitDistribution(uint feeRate, uint traderCutoff, uint collateralDeltaAmount, uint totalAmountOut)
        internal
        pure
        returns (uint traderFeeCutoff, uint puppetFee)
    {
        uint totalProfitDelta = getPlatformProfitFee(feeRate, collateralDeltaAmount - totalAmountOut);
        traderFeeCutoff = getPlatformTraderProfitFeeCutoff(traderCutoff, totalProfitDelta);

        puppetFee = totalProfitDelta - traderFeeCutoff;

        return (traderFeeCutoff, puppetFee);
    }

    function getUserGeneratedRevenueKey(IERC20 token, address from, address account) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(token, from, account));
    }

    function getRuleKey(address puppet, bytes32 routeKey) internal pure returns (bytes32) {
        return keccak256(abi.encode(puppet, routeKey));
    }

    function getRuleKey(address puppet, address trader, address collateralToken) internal pure returns (bytes32) {
        return keccak256(abi.encode(puppet, getRouteKey(trader, collateralToken)));
    }

    function getRouteKey(address trader, address collateralToken) internal pure returns (bytes32) {
        return keccak256(abi.encode(trader, collateralToken));
    }
}
