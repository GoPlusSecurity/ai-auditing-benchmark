    function getTradeFundingFeePure(
        int256 accFundingFeesPerOi,
        int256 endAccFundingFeesPerOi,
        uint256 collateral,
        uint32 leverage
    ) public pure returns (int256) {
        int256 accFundingDelta = endAccFundingFeesPerOi - accFundingFeesPerOi;
        int256 fundingFee =
            (accFundingDelta * (collateral * leverage).toInt256()) / int64(PRECISION_18) / int8(PRECISION_2);

        return (fundingFee != 0) ? fundingFee : (accFundingDelta > 0) ? int8(1) : int8(0);
    }
