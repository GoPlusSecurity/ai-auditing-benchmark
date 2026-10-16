    function _calcRateBondToErc20(bytes32 bondID, bytes32 poolID)
        internal
        returns (
            uint256 rateE8,
            uint256 bondPriceE8,
            uint256 swapPairPriceE8,
            int256 spreadE8
        )
    {
        (
            ,
            ,
            LatestPriceOracleInterface erc20Oracle,
            BondPricerInterface bondPricer,
            int16 feeBaseE4,
            bool isBondSale
        ) = _getVsErc20Pool(poolID);
        swapPairPriceE8 = _getLatestPrice(erc20Oracle);
        (bondPriceE8, spreadE8) = _calcBondPriceAndSpread(
            bondPricer,
            bondID,
            feeBaseE4
        );
        bondPriceE8 = _calcUsdPrice(bondPriceE8);
        rateE8 = bondPriceE8.mul(10**8).div(
            swapPairPriceE8,
            "ERC20 oracle price must be non-zero"
        );

        // `spreadE8` is less than 0.15 * 10**8.
        if (isBondSale) {
            rateE8 = rateE8.mul(uint256(10**8 + spreadE8)) / 10**8;
        } else {
            rateE8 = rateE8.mul(10**8) / uint256(10**8 + spreadE8);
        }
    }
