    function _calcBondPriceAndSpread(
        BondPricerInterface bondPricer,
        bytes32 bondID,
        int16 feeBaseE4
    ) internal returns (uint256 bondPriceE8, int256 spreadE8) {
        (, uint256 maturity, , ) = _getBond(_bondMakerContract, bondID);
        (
            bool isKnownBondType,
            BondType bondType,
            uint256[] memory points
        ) = _bondShapeDetector.getBondTypeByID(
            _bondMakerContract,
            bondID,
            BondType.NONE
        );
        require(isKnownBondType, "cannot calculate the price of this bond");

        uint256 untilMaturity = maturity.sub(
            _getBlockTimestampSec(),
            "the bond should not have expired"
        );
        uint256 oraclePriceE8 = _getLatestPrice(_priceOracleContract);
        uint256 oracleVolatilityE8 = _getVolatility(
            _volatilityOracleContract,
            untilMaturity.toUint64()
        );

        uint256 leverageE8;
        (bondPriceE8, leverageE8) = bondPricer.calcPriceAndLeverage(
            bondType,
            points,
            oraclePriceE8.toInt256(),
            oracleVolatilityE8.toInt256(),
            untilMaturity.toInt256()
        );
        spreadE8 = _calcSpread(oracleVolatilityE8, leverageE8, feeBaseE4);
    }
