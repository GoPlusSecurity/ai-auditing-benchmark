// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {MessageHashUtils} from "@openzeppelin/utils/cryptography/MessageHashUtils.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ERC721} from "@solmate/tokens/ERC721.sol";
import {ECDSA} from "@openzeppelin/utils/cryptography/ECDSA.sol";
import {ITradeMarketplace} from "../../interfaces/callbacks/ITradeMarketplace.sol";
import {Hash} from "../utils/Hash.sol";

contract TradeMarketplace is ITradeMarketplace {
    using Hash for ITradeMarketplace.Order;
    using MessageHashUtils for bytes32;
    using SafeTransferLib for ERC20;
    using SafeTransferLib for address;

    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    mapping(address => uint256) public minNonce;
    mapping(address => mapping(uint256 => bool)) public cancelled;

    /// @notice Used in compliance with EIP712
    uint256 internal immutable INITIAL_CHAIN_ID;
    bytes32 public immutable INITIAL_DOMAIN_SEPARATOR;

    string public name;
    bytes public constant VERSION = "1";

    constructor(string memory _name) {
        name = _name;
        INITIAL_CHAIN_ID = block.chainid;
        INITIAL_DOMAIN_SEPARATOR = _computeDomainSeparator();
    }

    function executeOrder(Order memory order) public override {
        _executeOrder(order, msg.sender);
    }

    function _executeOrder(Order memory order, address taker) internal {
        _isValidOrder(order);

        if (order.isAsk) {
            _transferCurrency(order.currency, taker, order.maker, order.price);
            ERC721(order.collection).safeTransferFrom(order.maker, taker, order.tokenId);
        } else {
            _transferCurrency(order.currency, order.maker, taker, order.price);
            ERC721(order.collection).safeTransferFrom(taker, order.maker, order.tokenId);
        }

        emit OrderExecuted(
            order.maker,
            taker,
            order.collection,
            order.tokenId,
            order.currency,
            order.price,
            order.nonce,
            order.expiration,
            order.isAsk
        );
    }

    function cancelOrder(uint256 nonce) public override {
        cancelled[msg.sender][nonce] = true;
    }

    function cancelAllOrders(uint256 nonce) public override {
        address user = msg.sender;
        uint256 currentMinNonce = minNonce[user];
        if (currentMinNonce >= nonce) {
            revert LowNonceError(user, nonce, currentMinNonce);
        }
        minNonce[user] = nonce;

        emit AllOrdersCancelled(user, nonce);
    }

    function orderHash(Order memory order) public pure override returns (bytes32) {
        return Hash.hash(order);
    }

    function isOrderCancelled(Order memory order) public view override returns (bool) {
        return _isOrderCancelled(order);
    }

    function _isOrderCancelled(Order memory order) private view returns (bool) {
        return cancelled[order.maker][order.nonce] || minNonce[order.maker] > order.nonce;
    }

    function _isValidOrder(Order memory order) private view {
        _hasValidSignature(order);

        if (order.expiration < block.timestamp) {
            revert OrderExpired();
        }

        if (_isOrderCancelled(order)) {
            revert OrderCancelled();
        }

        if (order.taker != address(0) && order.taker != msg.sender) {
            revert InvalidTaker();
        }
    }

    function _transferCurrency(address token, address from, address to, uint256 amount) private {
        if (from == address(this)) {
            if (token == ETH) {
                uint256 balance = address(this).balance;
                to.safeTransferETH(amount);
            } else {
                ERC20(token).safeTransfer(to, amount);
            }
        } else {
            if (token == ETH) {
                revert InvalidCurrencyError();
            }
            ERC20(token).safeTransferFrom(from, to, amount);
        }
    }

    function _hasValidSignature(Order memory order) private view {
        bytes32 hash = DOMAIN_SEPARATOR().toTypedDataHash(Hash.hash(order));
        address signer = ECDSA.recover(hash, order.signature);
        if (signer != order.maker) {
            revert InvalidSignature();
        }
    }

    /// @notice Get the domain separator requried to comply with EIP-712.
    function DOMAIN_SEPARATOR() public view returns (bytes32) {
        return block.chainid == INITIAL_CHAIN_ID ? INITIAL_DOMAIN_SEPARATOR : _computeDomainSeparator();
    }

    /// @notice Compute domain separator for EIP-712.
    /// @return The domain separator.
    function _computeDomainSeparator() private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(name)),
                keccak256(VERSION),
                block.chainid,
                address(this)
            )
        );
    }
}
