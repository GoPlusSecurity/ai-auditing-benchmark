    function _priceImpactFunction(
        uint256 netVolThreshold,
        uint256 priceImpactK,
        uint256 tradeSize,
        uint256 initialVol,
        uint256 midPrice,
        uint256 askPrice,
        uint256 bidPrice
    ) internal pure returns (uint256 priceImpactP) {
        uint256 spreadComponent = (askPrice - bidPrice) * PRECISION_18 * 100 / (midPrice * 2);
        uint256 dynamicComponent = 0;

        uint256 finalVol = tradeSize + initialVol;
        if (finalVol > netVolThreshold) {
            dynamicComponent = initialVol < netVolThreshold
                ? priceImpactK * (finalVol - netVolThreshold) * 100 / 2 / PRECISION_27
                : priceImpactK * (initialVol - netVolThreshold + tradeSize / 2) * 100 / PRECISION_27;
        }

        priceImpactP = spreadComponent + dynamicComponent;
        return priceImpactP;
    }
