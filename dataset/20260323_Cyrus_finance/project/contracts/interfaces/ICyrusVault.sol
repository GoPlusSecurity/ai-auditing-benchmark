pragma solidity ^0.8.20;

interface ICyrusVault {
   
function getAffiliate(address addr) external view returns (address);
function getAffiliatesNumber(address addr) external view returns (uint256[] memory);
function getAffiliateTurnover(address addr) external view returns (uint256);
}