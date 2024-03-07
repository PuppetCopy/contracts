// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IUniswapV3Pool} from "@uniswap/v3-core/interfaces/IUniswapV3Pool.sol";

contract MockUniswapV3Pool is IUniswapV3Pool {
    event PoolInitialized(uint160 sqrtPriceX96);
    // Variables to mock the responses

    uint160 public sqrtPriceX96;
    bool public unlocked = true;

    // Constructor to initialize the mock with specific values
    constructor(uint160 initialSqrtPriceX96) {
        sqrtPriceX96 = initialSqrtPriceX96;
        emit PoolInitialized(sqrtPriceX96);
    }

    // Mock implementation of slot0 to return predefined values
    function slot0()
        external
        view
        override
        returns (
            uint160 _sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            uint8 feeProtocol,
            bool _unlocked
        )
    {
        return (sqrtPriceX96, 0, 0, 0, 0, 0, unlocked);
    }

    // Implement other functions of the IUniswapV3Pool interface as needed for your tests
    // For simplicity, other functions can just revert or return dummy values if they are not used in your tests

    function observe(uint32[] calldata /*_secondsAgos*/ )
        external
        pure
        returns (int56[] memory, /*_tickCumulatives*/ uint160[] memory /*_secondsPerLiquidityCumulativeX128s*/ )
    {
        revert("Not implemented");
    }

    function setSqrtPriceX96(uint _ratio) external {
        // sqrtPriceX96 = SqrtMath.calcPriceToSqrtX96(_ratio);
    }

    // Add other necessary mock functions or variables here
    function factory() external view override returns (address) {}

    function token0() external view override returns (address) {}

    function token1() external view override returns (address) {}

    function fee() external view override returns (uint24) {}

    function tickSpacing() external view override returns (int24) {}

    function maxLiquidityPerTick() external view override returns (uint128) {}

    function feeGrowthGlobal0X128() external view override returns (uint) {}

    function feeGrowthGlobal1X128() external view override returns (uint) {}

    function protocolFees() external view override returns (uint128 _token0, uint128 _token1) {}

    function liquidity() external view override returns (uint128) {}

    function ticks(int24 tick)
        external
        view
        override
        returns (
            uint128 liquidityGross,
            int128 liquidityNet,
            uint feeGrowthOutside0X128,
            uint feeGrowthOutside1X128,
            int56 tickCumulativeOutside,
            uint160 secondsPerLiquidityOutsideX128,
            uint32 secondsOutside,
            bool initialized
        )
    {}

    function tickBitmap(int16 wordPosition) external view override returns (uint) {}

    function positions(bytes32 key)
        external
        view
        override
        returns (uint128 _liquidity, uint feeGrowthInside0LastX128, uint feeGrowthInside1LastX128, uint128 tokensOwed0, uint128 tokensOwed1)
    {}

    function observations(uint index)
        external
        view
        override
        returns (uint32 blockTimestamp, int56 tickCumulative, uint160 secondsPerLiquidityCumulativeX128, bool initialized)
    {}

    function snapshotCumulativesInside(int24 tickLower, int24 tickUpper)
        external
        view
        override
        returns (int56 tickCumulativeInside, uint160 secondsPerLiquidityInsideX128, uint32 secondsInside)
    {}

    function initialize(uint160 _sqrtPriceX96) external override {}

    function mint(address recipient, int24 tickLower, int24 tickUpper, uint128 amount, bytes calldata data)
        external
        override
        returns (uint amount0, uint amount1)
    {}

    function collect(address recipient, int24 tickLower, int24 tickUpper, uint128 amount0Requested, uint128 amount1Requested)
        external
        override
        returns (uint128 amount0, uint128 amount1)
    {}

    function burn(int24 tickLower, int24 tickUpper, uint128 amount) external override returns (uint amount0, uint amount1) {}

    function swap(address recipient, bool zeroForOne, int amountSpecified, uint160 sqrtPriceLimitX96, bytes calldata data)
        external
        override
        returns (int amount0, int amount1)
    {}

    function flash(address recipient, uint amount0, uint amount1, bytes calldata data) external override {}

    function increaseObservationCardinalityNext(uint16 observationCardinalityNext) external override {}

    function setFeeProtocol(uint8 feeProtocol0, uint8 feeProtocol1) external override {}

    function collectProtocol(address recipient, uint128 amount0Requested, uint128 amount1Requested)
        external
        override
        returns (uint128 amount0, uint128 amount1)
    {}
}
