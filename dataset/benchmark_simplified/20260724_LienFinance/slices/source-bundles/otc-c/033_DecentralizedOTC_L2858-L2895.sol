    function _calcRateLBT2ERC20(
        bytes32 sbtID,
        bytes32 erc20PoolID,
        uint256 maturity
    )
        internal
        returns (
            uint256 rateLBT2ERC20E8,
            uint256 lbtPriceE8,
            uint256 erc20PriceE8,
            int256 spreadE8
        )
    {
        PoolInfo memory pool = poolMap[erc20PoolID];
        (uint256 etherPriceE8, uint256 ethVolatilityE8) = _getOracleData();
        (, , uint256 strikePriceE8, ) = _bondMakerContract.getBond(sbtID);
        erc20PriceE8 = _getOraclePrice(erc20PoolID);

        (lbtPriceE8, spreadE8) = _calcLbtPriceAndSpread(
            strikePriceE8,
            etherPriceE8,
            ethVolatilityE8,
            maturity,
            pool.spread * 10 // feeBaseE4
        );
        uint256 rateE8 = lbtPriceE8.mul(10**8).div(
            erc20PriceE8,
            "ERC20 oracle price must be non-zero"
        );
        require(rateE8 > MIN_EXCHANGE_RATE_E8, "exchange rate is too small");
        // require(rateE8 < MAX_EXCHANGE_RATE_E8, "exchange rate is too large");

        if (pool.isLBTSellPool) {
            rateLBT2ERC20E8 = rateE8.mul(uint256(10**8 + spreadE8)) / (10**8);
        } else {
            rateLBT2ERC20E8 = rateE8.mul(uint256(10**8 - spreadE8)) / (10**8);
        }
    }
