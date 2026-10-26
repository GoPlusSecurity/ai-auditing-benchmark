// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface ITG {
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event ExcludedFromFee(address account);
    event IncludedToFee(address account);
    event OwnershipTransferred(address indexed user, address indexed newOwner);
    event Transfer(address indexed from, address indexed to, uint256 amount);

    function allowance(address, address) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address) external view returns (uint256);
    function decimals() external view returns (uint8);
    function distributor() external view returns (address);
    function dividendToUsersLp() external;
    function excludeFromDividend(address account) external;
    function excludeFromFee(address account) external;
    function excludeMultipleAccountsFromFee(address[] memory accounts) external;
    function getInviter(address user) external view returns (address);
    function inSwapAndLiquify() external view returns (bool);
    function includeInFee(address account) external;
    function isDividendExempt(address) external view returns (bool);
    function isExcludedFromFee(address account) external view returns (bool);
    function isInShareholders(address) external view returns (bool);
    function isPreacher(address user) external view returns (bool);
    function lastLPFeefenhongTime() external view returns (uint256);
    function launchedAtTimestamp() external view returns (uint40);
    function minDistribution() external view returns (uint256);
    function minPeriod() external view returns (uint256);
    function name() external view returns (string memory);
    function owner() external view returns (address);
    function presale() external view returns (bool);
    function setDistributorGasForLp(uint256 _distributorGasForLp) external;
    function setMinDistribution(uint256 _minDistribution) external;
    function setMinPeriod(uint256 _minPeriod) external;
    function setPresale() external;
    function shareholderIndexes(address) external view returns (uint256);
    function shareholders(uint256) external view returns (address);
    function symbol() external view returns (string memory);
    function tOwnedU(address user) external view returns (uint256 totalUbuy);
    function totalSupply() external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transferOwnership(address newOwner) external;
    function uniswapV2Pair() external view returns (address);
    function recycle(uint256 amount) external;
    function setInvite(address user, address parent) external;
    function inviter(address user) external view returns (address parent);
    function Invamount(address user) external view returns (uint256 total);
    function getReserveU() external view returns (uint112);
    function recommendList(address user) external view returns (uint256 total);
    function blindEx(address user,address parent) external;
}