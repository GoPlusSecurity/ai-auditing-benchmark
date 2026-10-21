// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

enum NodeType {
    USDT,
    XPL
}

enum NftType {
    SUPER,
    LARGE,
    SMALL
}

struct NftData {
    uint256 tokenId;
    NftType nftType;
    uint256 rate;
    address owner;
    uint256 purchaseTime;
    bool isActive;
}

interface INodeNFT {
    function isActiveNode(uint256 tokenId) external view returns (bool);
    function ownerOf(uint256 tokenId) external view returns (address);
    function smallRate() external view returns (uint256);
    function largeRate() external view returns (uint256);
    function superRate() external view returns (uint256);
    function nftDataList(
        uint256 tokenId
    ) external view returns (NftData memory);
    function getAllPower() external view returns (uint256);
    function balanceOf(address owner) external view returns (uint256 balance);
    function tokenOfOwnerByIndex(
        address owner,
        uint256 index
    ) external view returns (uint256);
}
