    function getTradeValuePure(uint256 collateral, int256 percentProfit, int256 rolloverFee, int256 fundingFee)
        public
        pure
        returns (uint256)
    {
        int256 signedCollateral = collateral.toInt256();
        int256 value =
            signedCollateral + (signedCollateral * percentProfit) / int32(PRECISION_6) / 100 - rolloverFee - fundingFee;

        if (value < 0) {
            value = 0;
        }

        return value.toUint256();
    }
