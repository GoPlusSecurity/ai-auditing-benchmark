    }

    function _fundFum(address to, uint minFumOut) internal returns (uint fumOut)
    {
        // 1. Load the stored state:
        LoadedState memory ls = loadState();
        ls.ethPool -= msg.value;    // Backing out the ETH just received, which our calculations should ignore

        // 2. Refresh the oracle price:
        (ls.ethUsdPrice, ls.oracleEthUsdPrice, ls.bidAskAdjustment) = checkForFreshOraclePrice(ls);

        // 3. Refresh timeSystemWentUnderwater, and replace ls.usmTotalSupply with the *effective* USM supply for FUM buys:
        uint debtRatio_;
        (ls.timeSystemWentUnderwater, ls.usmTotalSupply, debtRatio_) =
            checkIfUnderwater(ls.usmTotalSupply, ls.ethPool, ls.ethUsdPrice, ls.timeSystemWentUnderwater, block.timestamp);

        // 4. Calculate fumOut:
        uint fumSupply = fum.totalSupply();
        uint adjGrowthFactor;
        (fumOut, adjGrowthFactor) = fumFromFund(ls, fumSupply, msg.value, debtRatio_, isDuringPrefund());
        require(fumOut >= minFumOut, "Limit not reached");

        // 5. Update the in-memory LoadedState's bidAskAdjustment and price:
        ls.bidAskAdjustment = ls.bidAskAdjustment.wadMulUp(adjGrowthFactor);
        ls.ethUsdPrice = ls.ethUsdPrice.wadMulUp(adjGrowthFactor);

        // 6. Update the stored state and mint the user's new FUM:
        _storeState(ls);
        fum.mint(to, fumOut);
    }

    function _defundFum(address from, address payable to, uint fumToBurn, uint minEthOut) internal returns (uint ethOut)
    {
        // 1. Load the stored state:
        LoadedState memory ls = loadState();

        // 2. Refresh the oracle price:
        (ls.ethUsdPrice, ls.oracleEthUsdPrice, ls.bidAskAdjustment) = checkForFreshOraclePrice(ls);

        // 3. Calculate ethOut:
        uint fumSupply = fum.totalSupply();
        uint adjShrinkFactor;
        (ethOut, adjShrinkFactor) = ethFromDefund(ls, fumSupply, fumToBurn);
        require(ethOut >= minEthOut, "Limit not reached");

        // 4. Update the in-memory LoadedState's bidAskAdjustment and price:
        ls.bidAskAdjustment = ls.bidAskAdjustment.wadMulDown(adjShrinkFactor);
        ls.ethUsdPrice = ls.ethUsdPrice.wadMulDown(adjShrinkFactor);

        // 5. Check that the defund didn't leave debt ratio > MAX_DEBT_RATIO:
        uint newDebtRatio = debtRatio(ls.ethUsdPrice, ls.ethPool - ethOut, ls.usmTotalSupply);
        require(newDebtRatio <= MAX_DEBT_RATIO, "Debt ratio > max");

        // 6. Burn the input FUM, store the updated state, and return the user's ETH:
        fum.burn(from, fumToBurn);
        _storeState(ls);
        to.sendValue(ethOut);
    }

    /**
     * @notice Stores the current price (and oracle price), `bidAskAdjustment`, and `timeSystemWentUnderwater`.
     */
    function _storeState(LoadedState memory ls) internal {
        if (ls.timeSystemWentUnderwater != storedState.timeSystemWentUnderwater) {
            require(ls.timeSystemWentUnderwater <= type(uint32).max, "timeSystemWentUnderwater overflow");
            bool isUnderwater = (ls.timeSystemWentUnderwater != 0);
            bool wasUnderwater = (storedState.timeSystemWentUnderwater != 0);
            // timeSystemWentUnderwater should only change between 0 and non-0, never from one non-0 to another:
            require(isUnderwater != wasUnderwater, "Unexpected timeSystemWentUnderwater change");
            emit UnderwaterStatusChanged(isUnderwater);
        }

        uint priceToStore = ls.ethUsdPrice + HALF_TRILLION;
        unchecked { priceToStore /= TRILLION; }
        uint oraclePriceToStore;
        unchecked { oraclePriceToStore = ls.oracleEthUsdPrice / TRILLION; } // Already rounded: see checkForFreshOraclePrice()
        if (priceToStore != storedState.ethUsdPrice) {
            require(priceToStore <= type(uint64).max, "ethUsdPrice overflow");
            unchecked { emit PriceChanged(priceToStore * TRILLION, oraclePriceToStore * TRILLION); }
        }
        require(oraclePriceToStore <= type(uint64).max, "oracleEthUsdPrice overflow");

        require(ls.bidAskAdjustmentTimestamp <= type(uint32).max, "bidAskAdjustmentTimestamp overflow");
        uint adjustmentToStore = ls.bidAskAdjustment + HALF_TRILLION;
        unchecked { adjustmentToStore /= TRILLION; }
        if (adjustmentToStore != storedState.bidAskAdjustment) {
            require(adjustmentToStore <= type(uint64).max, "bidAskAdjustment overflow");
            unchecked { emit BidAskAdjustmentChanged(adjustmentToStore * TRILLION); }
        }

        (storedState.timeSystemWentUnderwater,
         storedState.ethUsdPrice, storedState.oracleEthUsdPrice,
         storedState.bidAskAdjustmentTimestamp, storedState.bidAskAdjustment) =
            (uint32(ls.timeSystemWentUnderwater),
             uint64(priceToStore), uint64(oraclePriceToStore),
             uint32(ls.bidAskAdjustmentTimestamp), uint64(adjustmentToStore));
    }

    // ____________________ Public Oracle view functions ____________________

    function latestPrice() public virtual override view returns (uint price) {
