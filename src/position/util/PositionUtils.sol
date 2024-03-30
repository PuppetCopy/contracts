// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Precision} from "./../../utils/Precision.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

library PositionUtils {
    function getPlatformMatchingFee(uint matchingFee, uint sizeDelta) internal pure returns (uint) {
        return Precision.applyBasisPoints(sizeDelta, matchingFee);
    }

    function getPlatformPerformanceFee(uint feeRate, uint profit) internal pure returns (uint) {
        return Precision.applyBasisPoints(profit, feeRate);
    }

    function getPlatformTraderProfitFeeCutoff(uint cutoffRate, uint profit) internal pure returns (uint) {
        return Precision.applyBasisPoints(profit, cutoffRate);
    }

    function getPlatformProfitDistribution(uint feeRate, uint traderCutoff, uint collateralDeltaAmount, uint totalAmountOut)
        internal
        pure
        returns (uint traderFeeCutoff, uint puppetFee)
    {
        uint totalProfitDelta = getPlatformPerformanceFee(feeRate, collateralDeltaAmount - totalAmountOut);
        traderFeeCutoff = getPlatformTraderProfitFeeCutoff(traderCutoff, totalProfitDelta);

        puppetFee = totalProfitDelta - traderFeeCutoff;

        return (traderFeeCutoff, puppetFee);
    }

    function getUserGeneratedRevenueKey(IERC20 token, address from, address account) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(token, from, account));
    }

    function getRuleKey(IERC20 collateralToken, address puppet, address trader) internal pure returns (bytes32) {
        return keccak256(abi.encode(collateralToken, puppet, trader));
    }

    function getAllownaceKey(IERC20 collateralToken, address puppet) internal pure returns (bytes32) {
        return keccak256(abi.encode(collateralToken, puppet));
    }

    function getFundingActivityKey(address puppet, address trader) internal pure returns (bytes32) {
        return keccak256(abi.encode(puppet, trader));
    }
}
