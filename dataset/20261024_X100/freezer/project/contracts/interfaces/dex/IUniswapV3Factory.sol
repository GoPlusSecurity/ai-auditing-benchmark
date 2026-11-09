// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @dev Uniswap v3 and PancakeSwap v3 factories share this call.
 */
interface IUniswapV3Factory {
    /**
     * @dev Returns the pool for a pair and fee tier, zero when none exists; token order is free.
     */
    function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address pool);
}
