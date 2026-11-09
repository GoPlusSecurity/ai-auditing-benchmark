// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IPancakeRouter {
  function factory() external pure returns (address);
  function WETH() external pure returns (address);
  function addLiquidity(address tokenA, address tokenB, uint256 amountADesired,
    uint256 amountBDesired, uint256 amountAMin, uint256 amountBMin,
    address to, uint256 deadline) external returns (uint256, uint256, uint256);
  function addLiquidityETH(address token, uint256 amountTokenDesired,
    uint256 amountTokenMin, uint256 amountETHMin, address to, uint256 deadline)
    external payable returns (uint256, uint256, uint256);
  function swapExactTokensForTokens(uint256 amountIn, uint256 amountOutMin,
    address[] calldata path, address to, uint256 deadline)
    external returns (uint256[] memory);
  function swapExactETHForTokens(uint256 amountOutMin, address[] calldata path,
    address to, uint256 deadline) external payable returns (uint256[] memory);
  function swapExactTokensForETH(uint256 amountIn, uint256 amountOutMin,
    address[] calldata path, address to, uint256 deadline)
    external returns (uint256[] memory);
  function getAmountsOut(uint256 amountIn, address[] calldata path)
    external view returns (uint256[] memory);
  function swapExactTokensForTokensSupportingFeeOnTransferTokens(
    uint256 amountIn, uint256 amountOutMin, address[] calldata path,
    address to, uint256 deadline) external;
  /// @dev A **tax-token-friendly** variant of ETH->token -- it **must** be used when an intermediate token charges a transfer tax.
  /// Pitfall: `swapExactETHForTokens` uses "exact input" to check each hop's K invariant; if an intermediate token in the path
  ///   (measured on mainnet: **BNI has a 2% transfer tax**) makes the next hop's pair receive less than quoted, the K check fails ->
  ///   the whole call reverts with `Pancake: K`. This variant advances by "actual received amount" and is the only viable multi-hop method.
  function swapExactETHForTokensSupportingFeeOnTransferTokens(
    uint256 amountOutMin, address[] calldata path,
    address to, uint256 deadline) external payable;
  function removeLiquidityETH(address token, uint256 liquidity,
    uint256 amountTokenMin, uint256 amountETHMin, address to, uint256 deadline)
    external returns (uint256 amountToken, uint256 amountETH);
}

interface IPancakePair {
  function token0() external view returns (address);
  function token1() external view returns (address);
  function getReserves() external view returns (uint112, uint112, uint32);
  function totalSupply() external view returns (uint256);
  function balanceOf(address owner) external view returns (uint256);
  function sync() external;
  function price0CumulativeLast() external view returns (uint256);
  function price1CumulativeLast() external view returns (uint256);
  /// @dev UniswapV2 pair's low-level swap -- for direct swapping on pairs **not registered with the Pancake factory**
  ///      (the mainnet FIST/USDT pair is deployed on FstSwap, which PancakeRouter cannot route to, so its swap must be called directly).
  ///      The caller must first transfer in tokenIn and compute amountOut itself by the constant product; the pair's K check rejects insufficient input.
  function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
}

interface IPancakeFactory {
  function getPair(address tokenA, address tokenB) external view returns (address);
  function createPair(address tokenA, address tokenB) external returns (address);
}

interface ISwapEngine {
  function swapAtoB() external returns (uint256);
  function swapBtoA() external returns (uint256);
}
