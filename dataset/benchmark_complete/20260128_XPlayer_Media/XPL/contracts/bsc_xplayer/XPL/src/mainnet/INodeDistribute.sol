// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface INodeDistribute {
    function tokenDistributorForUSDT() external view returns (address);
    function tokenDistributorForXPL() external view returns (address);
    function distributeShare(uint256) external;
    function distributeAllShare() external;
}