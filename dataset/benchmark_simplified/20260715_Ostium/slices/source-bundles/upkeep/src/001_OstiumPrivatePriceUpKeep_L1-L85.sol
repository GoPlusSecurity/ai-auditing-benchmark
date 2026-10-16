// SPDX-License-Identifier: MIT
import './interfaces/IOstiumRegistry.sol';
import './interfaces/IOstiumVerifier.sol';
import './interfaces/IOstiumTradingCallbacks.sol';
import './interfaces/IOstiumForwarded.sol';
import './interfaces/IOstiumPriceUpKeep.sol';

import '@openzeppelin/contracts/utils/math/SafeCast.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import './interfaces/IOwnable.sol';

pragma solidity ^0.8.24;

contract OstiumPrivatePriceUpKeep is IOstiumPriceUpKeep, IOstiumForwarded, Initializable {
    using SafeCast for uint256;

    IOstiumRegistry public registry;

    mapping(uint256 orderId => Order) public orders;
    mapping(address => bool) public isForwarder;

    uint16 public maxOrderAgeSeconds;

    constructor() {
        _disableInitializers();
    }

    function initialize(IOstiumRegistry _registry) external initializer {
        if (address(_registry) == address(0)) {
            revert WrongParams();
        }
        registry = _registry;
    }

    function initializeV2(uint16 _maxOrderAgeSeconds) external reinitializer(2) {
        if (_maxOrderAgeSeconds == 0) {
            revert WrongParams();
        }
        maxOrderAgeSeconds = _maxOrderAgeSeconds;
    }

    // Modifiers
    modifier onlyGov() {
        _onlyGov();
        _;
    }

    function _onlyGov() private view {
        if (msg.sender != registry.gov()) {
            revert NotGov(msg.sender);
        }
    }

    modifier onlyTimelock() {
        _onlyTimelock();
        _;
    }

    function _onlyTimelock() private view {
        if (msg.sender != IOwnable(address(registry)).owner()) {
            revert NotTimelock(msg.sender);
        }
    }

    modifier onlyRouter() {
        _onlyRouter();
        _;
    }

    function _onlyRouter() private view {
        if (msg.sender != registry.getContractAddress('priceRouter')) {
            revert NotRouter(msg.sender);
        }
    }

    function getPrice(uint256 orderId, uint16 pairIndex, OrderType orderType, uint256 timestamp) external onlyRouter {
        if (orders[orderId].initiated) {
            revert AlreadyInitiated(orderId);
        }
        bytes32 feed = IOstiumPairsStorage(registry.getContractAddress('pairsStorage')).pairFeed(pairIndex);
        orders[orderId] = Order(timestamp.toUint32(), pairIndex, orderType, true, feed);

        emit PriceRequestedV2(orderId, orderType, feed, timestamp);
    }

