    function getTradeValue(
        address trader,
        uint16 pairIndex,
        uint8 index,
        bool long,
        uint256 collateral,
        uint32 leverage,
        int256 percentProfit,
        uint32 maxLeverage
    ) external onlyCallbacks returns (uint256 tradeValue, uint256 liqMarginValue, int256 r, int256 f) {
        storeAccFundingFees(pairIndex);
        storeAccRolloverFees(pairIndex);

        TradeInitialAccFees memory t = tradeInitialAccFees[trader][pairIndex][index];

        r = getTradeRolloverFeePure(
            t.isRolloverSignNegative ? -int256(t.rollover) : int256(t.rollover),
            long ? pairRolloverFeesV2[pairIndex].accPerOiLong : pairRolloverFeesV2[pairIndex].accPerOiShort,
            collateral,
            leverage
        );
        f = getTradeFundingFeePure(
            t.funding,
            long ? pairFundingFees[pairIndex].accPerOiLong : pairFundingFees[pairIndex].accPerOiShort,
            collateral,
            leverage
        );

        liqMarginValue = getTradeLiquidationMargin(collateral, leverage, maxLeverage);
        tradeValue = getTradeValuePure(collateral, percentProfit, r, f);
    }
