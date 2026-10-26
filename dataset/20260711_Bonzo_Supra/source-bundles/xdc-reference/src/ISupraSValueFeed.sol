// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ISupraSValueFeed {
    struct priceFeed {
        uint256 round;
        uint256 decimals;
        uint256 time;
        uint256 price;
    }

    struct derivedData {
        int256 roundDifference;
        int256 timeDifference;
        uint256 derivedPrice;
        uint256 decimals;
    }

    function restrictedSetSupraStorage(uint256 _index, bytes32 _bytes) external;

    function restrictedSetTimestamp(uint256 _tradingPair, uint256 timestamp) external;

    function getTimestamp(uint256 _tradingPair) external view returns (uint256);

    function getRound(uint256 _tradingPair) external view returns (uint256);

    function getSvalue(uint64 _pairIndex) external view returns (bytes32, bool);

    function getSvalues(uint64[] memory _pairIndexes) external view returns (bytes32[] memory, bool[] memory);

    function getDerivedSvalue(uint256 _derivedPairId) external view returns (derivedData memory);

    function getSvalue(uint256 _pairIndex) external view returns (priceFeed memory);

    function getSvalues(uint256[] memory _pairIndexes) external view returns (priceFeed[] memory);
}
