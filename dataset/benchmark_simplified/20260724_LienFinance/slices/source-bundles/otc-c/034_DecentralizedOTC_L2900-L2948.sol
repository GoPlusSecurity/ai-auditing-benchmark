    function _calcLbtPriceAndSpread(
        uint256 strikePriceE8,
        uint256 etherPriceE8,
        uint256 ethVolatilityE8,
        uint256 maturity,
        int256 feeBaseE4
    ) internal view returns (uint256 lbtPriceE8, int256 spreadE8) {
        uint256 untilMaturity = maturity.sub(
            _getBlockTimestampSec(),
            "LBT should not have expired"
        );

        uint8 decimalsOfPrice = 0; // mutable
        {
            uint256 threshould = 1000000 * 10**8;
            while (threshould >= 10) {
                if (strikePriceE8 >= threshould) {
                    break;
                }
                decimalsOfPrice++;
                threshould /= 10;
            }
        }
        // assert(decimalsOfPrice >= 0 && decimalsOfPrice <= 14);

        uint256 lbtLeverageE4;
        {
            uint256 etherPrice = _applyDecimalGap(etherPriceE8, 8, decimalsOfPrice);
            uint256 strikePrice = _applyDecimalGap(strikePriceE8, 8, decimalsOfPrice);
            uint256 lbtPrice;
            (lbtPrice, lbtLeverageE4, ) = calcLbtPriceAndLeverage(
                etherPrice.toInt256(),
                strikePrice.toInt256(),
                ethVolatilityE8.toInt256(),
                untilMaturity.toInt256()
            );

            lbtPriceE8 = _applyDecimalGap(lbtPrice, decimalsOfPrice, 8);
        }

        uint256 volE8 = ethVolatilityE8 < 10**8 ? 10**8 : ethVolatilityE8 > 2 * 10**8
            ? 2 * 10**8
            : ethVolatilityE8;
        uint256 volTimesLevE4 = (volE8 * lbtLeverageE4) / 10**8;
        spreadE8 =
            feeBaseE4 *
            (feeBaseE4 < 0 || volTimesLevE4 < 10**4 ? 10**4 : volTimesLevE4).toInt256();
        spreadE8 = spreadE8 > MAX_SPREAD_E8 ? MAX_SPREAD_E8 : spreadE8;
    }
