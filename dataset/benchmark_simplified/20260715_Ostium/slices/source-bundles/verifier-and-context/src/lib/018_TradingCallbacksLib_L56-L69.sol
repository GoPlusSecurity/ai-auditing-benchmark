    function _currentPercentProfit(
        int256 openPrice,
        int256 currentPrice,
        bool buy,
        int32 leverage,
        int32 initialLeverage
    ) internal pure returns (int256 p, int256 maxPnlP) {
        maxPnlP = int16(MAX_GAIN_P) * int32(PRECISION_6) * int256(leverage)
            / (leverage > initialLeverage ? leverage : initialLeverage);

        p = (buy ? currentPrice - openPrice : openPrice - currentPrice) * int32(PRECISION_6) * leverage / openPrice;

        p = p > maxPnlP ? maxPnlP : p;
    }
