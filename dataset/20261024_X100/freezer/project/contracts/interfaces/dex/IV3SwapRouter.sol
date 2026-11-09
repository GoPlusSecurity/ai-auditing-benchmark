// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @dev Uniswap `SwapRouter02` and PancakeSwap `SmartRouter` single-pool swap.
 */
interface IV3SwapRouter {
    /**
     * @dev Parameters of {exactInputSingle}. `tokenIn`, `tokenOut` and `fee` identify the pool;
     * `recipient` receives the output; `amountIn` is the input to spend, zero meaning the
     * router's own balance; `amountOutMinimum` is the least acceptable output;
     * `sqrtPriceLimitX96` bounds the price, zero for no bound.
     */
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    /**
     * @dev Swaps an exact input within one pool and returns the output amount.
     */
    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);
}
