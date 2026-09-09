// SPDX-License-Identifier: MIT

pragma solidity 0.8.35;

interface IPancakeFactory {
    function feeTo() external view returns (address);

    function createPair(address tokenA, address tokenB) external returns (address);
}
