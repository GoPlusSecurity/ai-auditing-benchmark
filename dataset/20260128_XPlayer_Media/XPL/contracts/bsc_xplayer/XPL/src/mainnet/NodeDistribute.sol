// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
interface NodeDistribute {
    function distributeAllShare() external;
    function distributeShare(uint256 _nodeType) external;
    function tokenDistributorForShareholder() external view returns (address);
    function tokenDistributorForGenesis() external view returns (address);
}
