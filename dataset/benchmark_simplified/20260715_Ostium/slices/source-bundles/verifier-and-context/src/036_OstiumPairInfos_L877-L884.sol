    function getTradeLiquidationMargin(uint256 collateral, uint32 leverage, uint32 maxLeverage)
        public
        view
        returns (uint256)
    {
        uint256 rawAdjustedThreshold = uint256(liqMarginThresholdP) * leverage * PRECISION_6 / maxLeverage;
        return collateral * rawAdjustedThreshold / (100 * PRECISION_6);
    }
