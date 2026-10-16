    function getDynamicTradePriceImpact(
        int192 price,
        int192 ask,
        int192 bid,
        bool isOpen,
        IOstiumTradingStorage.Trade memory trade,
        IOstiumPairInfos pairInfos,
        uint256 collateralValue
    ) public returns (PriceImpactResult memory) {
        uint256 priceImpactK = pairInfos.getPairPriceImpactK(trade.pairIndex);

        uint256 priceImpactP;
        uint256 priceAfterImpact;
        if (priceImpactK == 0) {
            (priceImpactP, priceAfterImpact) = _getTradePriceImpact(price, ask, bid, isOpen, trade.buy);
            return PriceImpactResult({priceImpactP: priceImpactP, priceAfterImpact: priceAfterImpact, isDynamic: false});
        }

        (uint256 netVolThreshold, uint128 decayRate,) = pairInfos.pairDynamicSpreadParams(trade.pairIndex);

        (uint256 buyVolume, uint256 sellVolume, uint32 lastUpdateTimestamp) =
            pairInfos.pairDynamicSpreadState(trade.pairIndex);

        uint32 dt = block.timestamp > lastUpdateTimestamp ? uint32(block.timestamp) - lastUpdateTimestamp : 0;
        uint128 effectiveDecayRate = _getEffectiveDecayRate(buyVolume, sellVolume, decayRate, netVolThreshold);

        uint256 initialVolume = (trade.buy == isOpen) ? buyVolume : sellVolume;
        initialVolume = _decayVolumeWithPade(initialVolume, dt, effectiveDecayRate);

        uint256 tradeNotional = collateralValue * trade.leverage * PRECISION_10;

        priceAfterImpact = uint192(price);

        priceImpactP = _priceImpactFunction(
            netVolThreshold, priceImpactK, tradeNotional, initialVolume, uint192(price), uint192(ask), uint192(bid)
        );

        if (priceImpactP > 0) {
            if (isOpen == trade.buy) {
                priceAfterImpact = priceAfterImpact * (PRECISION_18 + (priceImpactP / 100)) / PRECISION_18;
            } else {
                if (priceImpactP < 100e18) {
                    priceAfterImpact = priceAfterImpact * (PRECISION_18 - (priceImpactP / 100)) / PRECISION_18;
                } else {
                    priceAfterImpact = 0;
                    priceImpactP = 100e18;
                }
            }
        }

        return PriceImpactResult({priceImpactP: priceImpactP, priceAfterImpact: priceAfterImpact, isDynamic: true});
    }
