    function fumFromFund(LoadedState memory ls, uint fumSupply, uint ethIn, uint debtRatio_, bool prefund)
        public pure returns (uint fumOut, uint adjGrowthFactor)
    {
        uint adjustedEthUsdPrice0 = adjustedEthUsdPrice(IUSM.Side.Buy, ls.ethUsdPrice, ls.bidAskAdjustment);
        uint fumBuyPrice0 = fumPrice(IUSM.Side.Buy, adjustedEthUsdPrice0, ls.ethPool, ls.usmTotalSupply, fumSupply, prefund);
        if (prefund) {
            // We're in the prefund period, so no fees - fumOut is just ethIn divided by the fixed prefund FUM price:
            adjGrowthFactor = WAD;
            fumOut = ethIn.wadDivDown(fumBuyPrice0);
        } else {
            // Create FUM at a sliding-up FUM price.  We follow the same broad strategy as in usmFromMint(): the effective ETH
            // price increases smoothly during the fund() operation, proportionally to the fraction by which the ETH pool
            // grows.  But there are a couple of extra nuances in the FUM case:
            //
            // 1. FUM is "leveraged"/"higher-delta" ETH, so minting 1 ETH worth of FUM should move the price by more than
            //    minting 1 ETH worth of USM does.  (More by a "net FUM delta" factor.)
            // 2. The theoretical FUM price is based on the ETH buffer (excess ETH beyond what's needed to cover the
            //    outstanding USM), which is itself affected by/during this fund operation...
            //
            // The code below uses a "reasonable approximation" to deal with those complications.  See also the discussion in:
            // https://jacob-eliosoff.medium.com/usm-minimalist-decentralized-stablecoin-part-4-fee-math-decisions-a5be6ecfdd6f

            { // Scope for adjGrowthFactor, to avoid the dreaded "stack too deep" error.  Thanks Uniswap v2 for the trick!
                // 1. Start by calculating the "net FUM delta" described above - the factor by which this operation will move
                // the ETH price more than a simple mint() operation would.  Calculating the pure, fluctuating theoretical
                // delta is a mess: we calculate the initial delta and pretend it stays fixed thereafter.  The theoretical
                // delta *decreases* during a fund() call (as the pool grows, the ETH/USD price increases, and FUM becomes less
                // leveraged), so holding it fixed at its initial value is "pessimistic", like we want - ensures we charge more
                // fees than the theoretical amount, not less.
                uint effectiveDebtRatio0 = debtRatio_.wadMin(MAX_DEBT_RATIO);
                uint netFumDelta;
                unchecked { netFumDelta = effectiveDebtRatio0.wadDivUp(WAD - effectiveDebtRatio0); }

                // 2. Given the delta, we can calculate the adjGrowthFactor (price impact): for mint() (delta 1), the factor
                // was poolChangeFactor**(1 / 2); now instead we use poolChangeFactor**(netFumDelta / 2).
                uint ethPool1 = ls.ethPool + ethIn;
                unchecked { adjGrowthFactor = ethPool1.wadDivUp(ls.ethPool).wadPowUp(netFumDelta / 2); }
            }

            // 3. Here we use the same simplifying trick as usmFromMint() above: we pretend our entire FUM purchase is done at
            // a single fixed price.  For that fixed FUM price, we again use the trick of taking the geometric average of the
            // starting and ending FUM buy prices, which we can calculate exactly now that we know the ending ETH pool quantity
            // (from ethIn) and the ending adjusted ETH/USD price (from the adjGrowthFactor calculated above).  This geometric
            // average isn't as accurate an approximation of the theoretical integral here as it was for usmFromMint(), since
            // the FUM buy price follows a less predictable curve than the USM buy price, but it's close enough for our
            // purposes: we mostly just want to charge funders a positive fee, that increases as a % of ethIn as ethIn gets
            // larger ("larger trades pay superlinearly larger fees").
            uint adjustedEthUsdPrice1 = adjustedEthUsdPrice0.wadMulUp(adjGrowthFactor.wadSquaredUp());
            uint fumBuyPrice1 = fumPrice(IUSM.Side.Buy, adjustedEthUsdPrice1, ls.ethPool, ls.usmTotalSupply, fumSupply,
                                         prefund);
            uint avgFumBuyPrice = fumBuyPrice0.wadMulUp(fumBuyPrice1).wadSqrtUp();      // Taking the geometric avg
            fumOut = ethIn.wadDivDown(avgFumBuyPrice);
        }
    }

    /**
     * @notice How much ETH a defunder currently gets back for fumIn FUM, accounting for adjustment and sliding prices.
     * @param fumIn The amount of FUM passed to `defund()`
     * @return ethOut The amount of ETH to receive in exchange
     */
    function ethFromDefund(LoadedState memory ls, uint fumSupply, uint fumIn)
        public pure returns (uint ethOut, uint adjShrinkFactor)
    {
        // Burn FUM at a sliding-down FUM price.  Our approximation technique here resembles the one in fumFromFund() above,
        // but we need to be even more clever this time...

        // 1. Calculating the initial FUM sell price we start from is no problem:
        uint adjustedEthUsdPrice0 = adjustedEthUsdPrice(IUSM.Side.Sell, ls.ethUsdPrice, ls.bidAskAdjustment);
        uint fumSellPrice0 = fumPrice(IUSM.Side.Sell, adjustedEthUsdPrice0, ls.ethPool, ls.usmTotalSupply, fumSupply, false);

        { // Scope for adjShrinkFactor, to avoid the dreaded "stack too deep" error.  Thanks Uniswap v2 for the trick!
            // 2. Now we want a "pessimistic" lower bound on the ending ETH pool qty.  We can get this by supposing the entire
            // burn happened at our initial fumSellPrice0: this is "optimistic" in terms of how much ETH we'd get back, but
            // "pessimistic" in the sense we want - how much ETH would be left in the pool:
            uint lowerBoundEthQty1 = ls.ethPool - fumIn.wadMulUp(fumSellPrice0);
            uint lowerBoundEthShrinkFactor1 = lowerBoundEthQty1.wadDivDown(ls.ethPool);

            // 3. From this "pessimistic" lower bound on the ending ETH qty, and a similarly pessimistic netFumDelta value of 4
            // (the netFumDelta when debt ratio is at the highest value it can end at here, MAX_DEBT_RATIO), we can calculate a
            // "pessimistic" lower bound on our ending adjustedEthUsdPrice, ie, overstating how large an impact our burn could
            // have on the ETH/USD price used to calculate our FUM sell price:
            uint adjustedEthUsdPrice1 = adjustedEthUsdPrice0.wadMulDown(lowerBoundEthShrinkFactor1.wadPowDown(FOUR_WAD));

            // 4. From adjustedEthUsdPrice1, we can calculate a pessimistic (upper-bound) debtRatio2 we'll end up at after the
            // defund operation, and from debtRatio2, a pessimistic (upper-bound) netFumDelta2 we can hold fixed during the
            // calculation:
            uint debtRatio1 = debtRatio(adjustedEthUsdPrice1, lowerBoundEthQty1, ls.usmTotalSupply);
            uint debtRatio2 = debtRatio1.wadMin(MAX_DEBT_RATIO);    // defund() fails anyway if dr ends > MAX, so cap it at MAX
            uint netFumDelta2;
            unchecked { netFumDelta2 = WAD.wadDivUp(WAD - debtRatio2) - WAD; }

            // 5. Combining lowerBoundEthShrinkFactor1 and netFumDelta2 gives us our final, pessimistic adjShrinkFactor, from
            // our standard formula adjChangeFactor = ethChangeFactor**(netFumDelta / 2):
            unchecked { adjShrinkFactor = lowerBoundEthShrinkFactor1.wadPowDown(netFumDelta2 / 2); }
        }

        // 6. And adjShrinkFactor tells us the adjustedEthUsdPrice2 we'll end the operation at, from which we can also
        // calculate the instantaneous FUM sell price we'll end the operation at, just as we calculated our ending fumBuyPrice1
        // in fumFromFund():
        uint adjustedEthUsdPrice2 = adjustedEthUsdPrice0.wadMulDown(adjShrinkFactor.wadSquaredDown());
        uint fumSellPrice2 = fumPrice(IUSM.Side.Sell, adjustedEthUsdPrice2, ls.ethPool, ls.usmTotalSupply, fumSupply, false);

        // 7. We now know the starting fumSellPrice0, and the ending fumSellPrice2.  We want to combine these to get a single
        // avgFumSellPrice we can use for the entire defund operation, which will trivially give us ethOut.  But taking the
        // geometric average again, as we did in usmFromMint() and fumFromFund(), is dicey in the defund() case: fumSellPrice2
        // could be arbitrarily close to 0, which would make avgFumSellPrice arbitrarily close to 0, which would have the
        // highly perverse result that a *larger* fumIn returns strictly *less* ETH!  What alternative to geometric average
        // gives the best results here is a complicated problem, but one simple option that avoids the avgFumSellPrice = 0 flaw
        // is to just take the arithmetic average instead, (fumSellPrice0 + fumSellPrice2) / 2:
        uint avgFumSellPrice = fumSellPrice0 + fumSellPrice2;
        unchecked { avgFumSellPrice /= 2; }
        ethOut = fumIn.wadMulDown(avgFumSellPrice);
    }
}
