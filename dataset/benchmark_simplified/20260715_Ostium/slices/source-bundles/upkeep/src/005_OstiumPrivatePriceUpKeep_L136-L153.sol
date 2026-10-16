    function fulfill(PriceUpKeepAnswer memory a) internal {
        Order memory r = orders[a.orderId];

        IOstiumTradingCallbacks c = IOstiumTradingCallbacks(registry.getContractAddress('callbacks'));

        if (r.orderType == OrderType.MARKET_OPEN) {
            c.openTradeMarketCallback(a);
        } else if (r.orderType == OrderType.MARKET_CLOSE) {
            c.closeTradeMarketCallback(a);
        } else if (r.orderType == OrderType.LIMIT_OPEN) {
            c.executeAutomationOpenOrderCallback(a);
        } else if (r.orderType == OrderType.LIMIT_CLOSE) {
            c.executeAutomationCloseOrderCallback(a);
        } else if (r.orderType == OrderType.REMOVE_COLLATERAL) {
            c.handleRemoveCollateral(a);
        }
        delete orders[a.orderId];
    }
