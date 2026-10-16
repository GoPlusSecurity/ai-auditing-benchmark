    function _getVsErc20Pool(bytes32 poolID)
        internal
        view
        isExsistentVsErc20Pool(poolID)
        returns (
            address seller,
            ERC20 swapPairToken,
            LatestPriceOracleInterface swapPairOracle,
            BondPricerInterface bondPricer,
            int16 feeBaseE4,
            bool isBondSale
        )
    {
        VsErc20Pool memory exchangePair = _vsErc20Pool[poolID];
        seller = exchangePair.seller;
        swapPairToken = exchangePair.swapPairToken;
        swapPairOracle = exchangePair.swapPairOracle;
        bondPricer = exchangePair.bondPricer;
        feeBaseE4 = exchangePair.feeBaseE4;
        isBondSale = exchangePair.isBondSale;
    }
