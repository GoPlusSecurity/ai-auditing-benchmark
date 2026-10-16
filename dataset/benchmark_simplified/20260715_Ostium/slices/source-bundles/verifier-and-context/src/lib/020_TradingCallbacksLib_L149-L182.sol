    function getTradeAndPriceData(
        IOstiumPriceUpKeep.PriceUpKeepAnswer calldata a,
        IOstiumTradingStorage.Trade calldata t,
        IOstiumPairInfos pairInfos,
        uint32 initialLeverage,
        uint32 maxLeverage,
        uint256 collateral,
        bool isMarketPrice
    ) external returns (TradeValueResult memory, PriceImpactResult memory) {
        PriceImpactResult memory result =
            getDynamicTradePriceImpact(a.price, a.ask, a.bid, false, t, pairInfos, collateral);

        (int256 profitP,) = currentPercentProfit(
            t.openPrice.toInt256(),
            isMarketPrice ? a.price : result.priceAfterImpact.toInt256(),
            t.buy,
            int32(t.leverage),
            int32(initialLeverage)
        );

        (uint256 tradeValue, uint256 liqMarginValue, int256 rolloverFees, int256 fundingFees) =
            pairInfos.getTradeValue(t.trader, t.pairIndex, t.index, t.buy, collateral, t.leverage, profitP, maxLeverage);

        return (
            TradeValueResult({
                tradeValue: tradeValue,
                liqMarginValue: liqMarginValue,
                rolloverFees: rolloverFees,
                fundingFees: fundingFees,
                profitP: profitP
            }),
            result
        );
    }
