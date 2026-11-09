// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IAccounting {
    function getAPerUsd() external returns (uint256);
    function getBPerUsd() external returns (uint256);
    function getWbnbPerUsd() external returns (uint256);
    function getSwapPrices() external view returns (uint256 aPerUsd, uint256 bPerUsd, uint256 wbnbPerUsd);
}
