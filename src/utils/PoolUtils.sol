// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

// https://github.com/Uniswap/v3-core/blob/d8b1c635c275d2a9450bd6a78f3fa2484fef73eb/contracts/libraries/TickMath.sol#L15
library PoolUtils {
    int24 constant MIN_TICK = -887272;
    int24 constant MAX_TICK = -MIN_TICK;
    uint constant SCALE_FACTOR = 1 << 192;

    function calcSqrtRatioAtTick(int24 tick) internal pure returns (uint160 sqrtPriceX96) {
        uint absTick = tick < 0 ? uint(-int(tick)) : uint(int(tick));
        require(absTick <= SafeCast.toUint256(MAX_TICK), "T");

        uint ratio = absTick & 0x1 != 0 ? 0xfffcb933bd6fad37aa2d162d1a594001 : 0x100000000000000000000000000000000;
        if (absTick & 0x2 != 0) ratio = (ratio * 0xfff97272373d413259a46990580e213a) >> 128;
        if (absTick & 0x4 != 0) ratio = (ratio * 0xfff2e50f5f656932ef12357cf3c7fdcc) >> 128;
        if (absTick & 0x8 != 0) ratio = (ratio * 0xffe5caca7e10e4e61c3624eaa0941cd0) >> 128;
        if (absTick & 0x10 != 0) ratio = (ratio * 0xffcb9843d60f6159c9db58835c926644) >> 128;
        if (absTick & 0x20 != 0) ratio = (ratio * 0xff973b41fa98c081472e6896dfb254c0) >> 128;
        if (absTick & 0x40 != 0) ratio = (ratio * 0xff2ea16466c96a3843ec78b326b52861) >> 128;
        if (absTick & 0x80 != 0) ratio = (ratio * 0xfe5dee046a99a2a811c461f1969c3053) >> 128;
        if (absTick & 0x100 != 0) ratio = (ratio * 0xfcbe86c7900a88aedcffc83b479aa3a4) >> 128;
        if (absTick & 0x200 != 0) ratio = (ratio * 0xf987a7253ac413176f2b074cf7815e54) >> 128;
        if (absTick & 0x400 != 0) ratio = (ratio * 0xf3392b0822b70005940c7a398e4b70f3) >> 128;
        if (absTick & 0x800 != 0) ratio = (ratio * 0xe7159475a2c29b7443b29c7fa6e889d9) >> 128;
        if (absTick & 0x1000 != 0) ratio = (ratio * 0xd097f3bdfd2022b8845ad8f792aa5825) >> 128;
        if (absTick & 0x2000 != 0) ratio = (ratio * 0xa9f746462d870fdf8a65dc1f90e061e5) >> 128;
        if (absTick & 0x4000 != 0) ratio = (ratio * 0x70d869a156d2a1b890bb3df62baf32f7) >> 128;
        if (absTick & 0x8000 != 0) ratio = (ratio * 0x31be135f97d08fd981231505542fcfa6) >> 128;
        if (absTick & 0x10000 != 0) ratio = (ratio * 0x9aa508b5b7a84e1c677de54f3e99bc9) >> 128;
        if (absTick & 0x20000 != 0) ratio = (ratio * 0x5d6af8dedb81196699c329225ee604) >> 128;
        if (absTick & 0x40000 != 0) ratio = (ratio * 0x2216e584f5fa1ea926041bedfe98) >> 128;
        if (absTick & 0x80000 != 0) ratio = (ratio * 0x48a170391f7dc42444e8fa2) >> 128;

        if (tick > 0) ratio = type(uint).max / ratio;

        // this divides by 1<<32 rounding up to go from a Q128.128 to a Q128.96.
        // we then downcast because we know the result always fits within 160 bits due to our tick input constraint
        // we round up in the division so getTickAtSqrtRatio of the output price is always consistent
        sqrtPriceX96 = uint160((ratio >> 32) + (ratio % (1 << 32) == 0 ? 0 : 1));
    }

    function calcSqrtTwapX96(IUniswapV3Pool pool, uint32 twapInterval) internal view returns (uint160 sqrtPriceX96) {
        if (twapInterval == 0) {
            (sqrtPriceX96,,,,,,) = pool.slot0();
        } else {
            uint32[] memory secondAgos = new uint32[](2);
            secondAgos[0] = twapInterval;
            secondAgos[1] = 0;

            (int56[] memory tickCumulatives,) = pool.observe(secondAgos);
            int56 tickCumulativesDelta = tickCumulatives[1] - tickCumulatives[0];

            int24 timeWeightedAverageTick = int24(tickCumulativesDelta / int32(twapInterval));

            // Always round to negative infinity
            if (tickCumulativesDelta < 0 && (tickCumulativesDelta % int32(twapInterval) != 0)) {
                timeWeightedAverageTick--;
            }

            sqrtPriceX96 = calcSqrtRatioAtTick(timeWeightedAverageTick);
        }
    }

    function calcSqrtPriceX96ToUint(uint160 sqrtPriceX96, uint8 token0Decimals) internal pure returns (uint priceX96) {
        uint numerator1 = uint(sqrtPriceX96) ** 2;
        uint numerator2 = 10 ** token0Decimals;
        return numerator1 * numerator2 / SCALE_FACTOR;
    }

    function getTwapPrice(IUniswapV3Pool pool, uint8 token0Decimals, uint32 twapInterval) internal view returns (uint priceX96) {
        uint160 sqrtPriceX96 = calcSqrtTwapX96(pool, twapInterval);

        return calcSqrtPriceX96ToUint(sqrtPriceX96, token0Decimals);
    }

    function getTwapMedianPrice(IUniswapV3Pool[] memory poolList, uint32 twapInterval) internal view returns (uint medianPrice) {
        uint sourceListLength = poolList.length;

        uint[] memory priceList = new uint[](sourceListLength);

        // Initialize the first element
        priceList[0] = getTwapPrice(poolList[0], 18, twapInterval);

        for (uint i = 1; i < sourceListLength; i++) {
            uint currentPrice = getTwapPrice(poolList[i], 18, twapInterval);

            uint j = i;
            while (j > 0 && priceList[j - 1] > currentPrice) {
                priceList[j] = priceList[j - 1];
                j--;
            }
            priceList[j] = currentPrice;
        }

        uint medianIndex = (sourceListLength - 1) / 2; // Index of the median after the array is sorted
        medianPrice = priceList[medianIndex];
    }
}
