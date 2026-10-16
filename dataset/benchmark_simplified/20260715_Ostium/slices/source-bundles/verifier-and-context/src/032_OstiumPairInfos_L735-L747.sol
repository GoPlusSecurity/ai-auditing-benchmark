    function getTradeRolloverFeePure(
        int256 accRolloverFeesPerCollateral,
        int256 endAccRolloverFeesPerCollateral,
        uint256 collateral,
        uint32 leverage
    ) public pure returns (int256) {
        int256 accRolloverDelta =
            endAccRolloverFeesPerCollateral - accRolloverFeesPerCollateral;
        int256 rolloverFee =
            (accRolloverDelta * (collateral * leverage).toInt256()) / int64(PRECISION_18) / int8(PRECISION_2);

        return (rolloverFee != 0) ? rolloverFee : (accRolloverDelta > 0) ? int256(1) : int256(0);
    }
