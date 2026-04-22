// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

interface ILiquidityToken {
    function totalSupply() external view returns (uint256);
    function mint(address to, uint256 amount) external;
    function burnFrom(address from, uint256 amount) external;
    function initialize(string memory name, string memory symbol, address owner) external;
}

