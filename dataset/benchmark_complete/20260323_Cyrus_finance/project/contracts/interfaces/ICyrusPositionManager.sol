pragma solidity ^0.8.20;


struct MintCyrusParams {
    uint256 strategyId;
    uint256 amount;
    uint256 start;
    uint256 finish;
}

 struct PositionInfo{
        uint256 strategyId; 
        uint256 amount; 
        uint256 start; 
        uint256 finish; 
        uint256 totalClaimed; 
        uint256 lastClaimed; 
        uint256 unclaimed;
    }

interface ICyrusPositionManager {
    function mint(address to, MintCyrusParams calldata params) external returns(uint256);
    function updatePosition(uint256 tokenId, PositionInfo calldata params) external;
    function getPosition(uint256 tokenId) external view returns(PositionInfo memory);
    function getPositions(uint256[] calldata tokenIds) external view returns(PositionInfo[] memory);
    function ownerOf(uint256 tokenId) external view returns (address owner);
    function getPositionsValue(address addr) external view returns (uint256 value);
    function tokensOfOwner(address owner) external view returns (uint256[] memory); 
}