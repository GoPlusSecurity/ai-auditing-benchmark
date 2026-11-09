// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;
import {IPancakeRouter, IPancakePair} from "../interfaces/IPancake.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// DEX interaction wrapper: unified swap/addLP interface + slippage protection
library DexSwapper {
  using SafeERC20 for IERC20;

  uint256 internal constant DEFAULT_SLIPPAGE_BP = 500; // 5% default slippage
  uint256 internal constant MAX_SLIPPAGE_BP = 9900;    // L-15-fix: max 99%, prevents slippageBp=10000 causing minOut=0 with no protection

  // L-15-fix: slippageBp upper-bound check, preventing an accidental 10000 (equivalent to no slippage protection)
  function _checkSlippage(uint256 slippageBp) private pure {
    if (slippageBp > MAX_SLIPPAGE_BP) revert DexSwapper_SlippageTooHigh(slippageBp);
  }
  error DexSwapper_SlippageTooHigh(uint256 bp);

  // Swap exact token for token (specified path)
  function swapExactTokensForTokens(
    IPancakeRouter router, address tokenIn, address tokenOut,
    uint256 amountIn, uint256 slippageBp, address to, uint256 deadline
  ) internal returns (uint256 amountOut) {
    _checkSlippage(slippageBp);
    address[] memory path = _buildPath(tokenIn, tokenOut, router.WETH());
    uint256[] memory amounts = router.getAmountsOut(amountIn, path);
    uint256 minOut = (amounts[amounts.length - 1] * (10000 - slippageBp)) / 10000;
    IERC20(tokenIn).forceApprove(address(router), amountIn);
    amounts = router.swapExactTokensForTokens(amountIn, minOut, path, to, deadline);
    return amounts[amounts.length - 1];
  }

  // Swap ETH for token
  function swapETHForTokens(
    IPancakeRouter router, address tokenOut,
    uint256 slippageBp, address to, uint256 deadline
  ) internal returns (uint256 amountOut) {
    _checkSlippage(slippageBp);
    address[] memory path = new address[](2);
    path[0] = router.WETH();
    path[1] = tokenOut;
    uint256[] memory amounts = router.getAmountsOut(msg.value, path);
    uint256 minOut = (amounts[1] * (10000 - slippageBp)) / 10000;
    amounts = router.swapExactETHForTokens{value: msg.value}(minOut, path, to, deadline);
    return amounts[1];
  }

  // Add dual-token LP
  function addLiquidity(
    IPancakeRouter router, address tokenA, address tokenB,
    uint256 amountA, uint256 amountB,
    uint256 slippageBp, address to, uint256 deadline
  ) internal returns (uint256 amountAUsed, uint256 amountBUsed, uint256 lpAmt) {
    _checkSlippage(slippageBp);
    uint256 minA = (amountA * (10000 - slippageBp)) / 10000;
    uint256 minB = (amountB * (10000 - slippageBp)) / 10000;
    IERC20(tokenA).forceApprove(address(router), amountA);
    IERC20(tokenB).forceApprove(address(router), amountB);
    (amountAUsed, amountBUsed, lpAmt) = router.addLiquidity(
      tokenA, tokenB, amountA, amountB, minA, minB, to, deadline
    );
  }

  // Build path
  // Requirement 2.0 L144: pair topology = OSK/FIST + FIST/USDT + FISTDAO/BNI.
  //   Non-WETH pairs are connected **directly in two hops**, without a WETH intermediate -- a WETH intermediate would revert
  //   on the real chain due to missing OSK/WBNB and FIST/WBNB pairs.
  //   (The original implementation forced three hops [in, WETH, out] for non-WETH pairs; corrected to direct connection.)
  function _buildPath(address tokenIn, address tokenOut, address /* weth */)
    private pure returns (address[] memory path)
  {
    path = new address[](2);
    path[0] = tokenIn;
    path[1] = tokenOut;
  }

  // Estimate LP market cap (denominated in USDT, precision follows USDT decimals)
  // Note: this is a simplified estimate for now -- it returns USDT reserve x2 only when the pair contains USDT; otherwise it returns 0 (a router-based conversion to USDT is not implemented). The router parameter is currently unused.
  function estimateLpMarketCapUsd(
    IPancakeRouter /* router */, address lpPair, address usdt
  ) internal view returns (uint256 mcapUsd) {
    (uint112 r0, uint112 r1,) = IPancakePair(lpPair).getReserves();
    address t0 = IPancakePair(lpPair).token0();
    address t1 = IPancakePair(lpPair).token1();
    // when the pair contains USDT, market cap ≈ USDT reserve x2 (assuming both tokens are equal in value); otherwise return 0 (cross-path conversion not implemented)
    if (t0 == usdt) return uint256(r0) * 2;
    if (t1 == usdt) return uint256(r1) * 2;
    return 0;
  }
}
// 0xCAFEBABE - dex wrapper done
