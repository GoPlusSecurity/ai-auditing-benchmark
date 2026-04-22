// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
}

interface IUniswapV2Router02 {
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}

interface IUniswapV2Pair {
    function sync() external;
}

interface ITG {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function uniswapV2Pair() external view returns (address);
}

contract TGing {
    IUniswapV2Router02 public immutable ROUTER;
    IERC20 public immutable USDT;
    ITG public immutable TG;

    constructor(address tg) {
        ROUTER = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
        TG = ITG(tg);
    }

    function swapTGToUSDT(uint256 tokenAmount) public {
        TG.transferFrom(msg.sender, address(this), tokenAmount);

        address[] memory path = new address[](2);
        path[0] = address(TG);
        path[1] = address(USDT);

        ROUTER.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            msg.sender,
            block.timestamp
        );
    }

    function sync() external {
        uint256 w_bal = IERC20(USDT).balanceOf(address(this));
        address pair = TG.uniswapV2Pair();
        IERC20(USDT).transfer(pair, w_bal);
        IUniswapV2Pair(pair).sync();
    }
}
