    function _getTradePriceImpact(int192 price, int192 ask, int192 bid, bool isOpen, bool isLong)
        internal
        pure
        returns (uint256 priceImpactP, uint256 priceAfterImpact)
    {
        if (price == 0) {
            return (0, 0);
        }
        bool aboveSpot = (isOpen == isLong);

        int192 usedPrice = aboveSpot ? ask : bid;

        priceImpactP = (SignedMath.abs(price - usedPrice) * PRECISION_18 * 100 / uint192(price));

        return (priceImpactP, uint192(usedPrice));
    }
