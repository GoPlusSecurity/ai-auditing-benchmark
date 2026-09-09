// SPDX-License-Identifier: MIT

pragma solidity 0.8.35;

interface IPancakePair {
    function totalSupply() external view returns (uint256);

    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);

    function price1CumulativeLast() external view returns (uint256);

    function kLast() external view returns (uint256);

    function mint(address to) external returns (uint256 liquidity);

    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
}
