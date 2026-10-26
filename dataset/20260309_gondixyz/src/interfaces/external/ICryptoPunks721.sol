// SPDX-License-Identifier: MIT

pragma solidity ^0.8.21;

import {IERC721} from "@openzeppelin/token/ERC721/IERC721.sol";

interface ICryptoPunks721 is IERC721 {
    function licensingTerms() external pure returns (string memory);
    function wrapPunk(uint256 punkIndex) external;
    function wrapPunkBatch(uint256[] calldata punkIndexes) external;
    function unwrapPunk(uint256 punkIndex) external;
    function unwrapPunkBatch(uint256[] calldata punkIndexes) external;
    function migrateLegacyWrappedPunks(uint256[] calldata punkIndexes) external;
    function rescuePunk(uint256 punkIndex) external;
    function punkProxyForUser(address user) external view returns (address);
    function tokensOfOwner(address owner) external view returns (uint256[] memory);
    function totalSupply() external view returns (uint256);
}
