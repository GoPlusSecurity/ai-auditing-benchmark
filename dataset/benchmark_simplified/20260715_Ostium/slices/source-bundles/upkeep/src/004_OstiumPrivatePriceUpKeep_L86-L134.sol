    function performUpkeep(bytes calldata performData) external {
        if (!isForwarder[msg.sender]) {
            revert NotForwarder(msg.sender);
        }
        (bytes memory report, uint256 orderId) = abi.decode(performData, (bytes, uint256));

        Order memory order = orders[orderId];

        if (!order.initiated) {
            revert NotInitiated(orderId);
        }

        IOstiumVerifier verifierProxy = IOstiumVerifier(registry.getContractAddress('ostiumVerifier'));
        bytes memory verifierResponse = verifierProxy.verify(report);

        bytes32 reportFeedId;
        uint32 timestamp;
        bool isMarketOpen;

        PriceUpKeepAnswer memory a;

        a.orderId = orderId;

        (reportFeedId, timestamp, a.price, a.bid, a.ask, isMarketOpen, a.isDayTradingClosed) =
            abi.decode(verifierResponse, (bytes32, uint32, int192, int192, int192, bool, bool));

        if (!isMarketOpen) {
            delete a.price;
            delete a.bid;
            delete a.ask;
        }

        // Backward compatibility: if feedId is not set (old orders before upgrade), fetch from storage
        bytes32 expectedFeedId = order.feedId;
        if (expectedFeedId == bytes32(0)) {
            expectedFeedId = IOstiumPairsStorage(registry.getContractAddress('pairsStorage')).pairFeed(order.pairIndex);
        }

        if (
            expectedFeedId != reportFeedId || block.timestamp > order.timestamp + maxOrderAgeSeconds
                || timestamp < order.timestamp
        ) {
            revert InvalidPrice(orderId);
        }

        fulfill(a);

        emit PriceReceived(orderId, order.pairIndex, a.price, 0);
    }
