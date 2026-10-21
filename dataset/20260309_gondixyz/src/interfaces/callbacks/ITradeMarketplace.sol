// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/utils/cryptography/ECDSA.sol";

interface ITradeMarketplace {
    struct Order {
        address maker;
        address taker;
        address collection;
        uint256 tokenId;
        address currency;
        uint256 price;
        uint256 nonce;
        uint256 expiration;
        bool isAsk;
        bytes signature;
    }

    event OrderExecuted(
        address indexed maker,
        address indexed taker,
        address indexed collection,
        uint256 tokenId,
        address currency,
        uint256 price,
        uint256 nonce,
        uint256 expiration,
        bool isAsk
    );
    event AllOrdersCancelled(address indexed user, uint256 nonce);

    error OrderExpired();
    error OrderCancelled();
    error InvalidTaker();
    error LowNonceError(address user, uint256 nonce, uint256 currentMinNonce);
    error InvalidSignature();
    error InvalidCurrencyError();

    function executeOrder(Order memory order) external;
    function cancelOrder(uint256 nonce) external;
    function cancelAllOrders(uint256 nonce) external;
    function isOrderCancelled(Order memory order) external view returns (bool);
    function orderHash(Order memory order) external view returns (bytes32);
}
