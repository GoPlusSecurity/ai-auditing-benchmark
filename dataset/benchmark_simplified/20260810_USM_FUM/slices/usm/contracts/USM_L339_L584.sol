    function checkForFreshOraclePrice(LoadedState memory ls)
        public view returns (uint price, uint oraclePrice, uint adjustment)
    {
        oraclePrice = oracle.latestPrice() + HALF_TRILLION; // Round for comparison below (we only store millionths precision)
        unchecked { oraclePrice = oraclePrice / TRILLION * TRILLION; }  // Zeroing out the last 12 digits

        adjustment = ls.bidAskAdjustment;

        if (oraclePrice == ls.oracleEthUsdPrice) {          // Oracle price unchanged from last time, so keep our stored price
            price = ls.ethUsdPrice;
        } else {
            price = oraclePrice;
            if (ls.ethUsdPrice != 0) {                      // If old price is 0, don't try to use it to adjust bidAskAdj...
                /**
                 * This is a bit subtle.  We want to update the mid stored price to the oracle's fresh value, while updating
                 * bidAskAdjustment in such a way that the currently adjusted (more expensive than mid) side gets no
                 * cheaper/more favorably priced for users.  Example:
                 *
                 * 1. storedPrice = $1,000, and bidAskAdjustment = 1.02.  So, our current ETH buy price is $1,020, and our
                 *    current ETH sell price is $1,000 (mid).
                 * 2. The oracle comes back with a fresh price of $990.
                 * 3. The currently adjusted price is buy price (ie, adj > 1).  So, we want to:
                 *    a) Update storedPrice (mid) to $990.
                 *    b) Update bidAskAdj to ensure that buy price remains >= $1,020.
                 * 4. We do this by upping bidAskAdj 1.02 -> 1.0303.  Then the new buy price will remain $990 * 1.0303 =
                 *    $1,020.  The sell price will remain the unadjusted mid: formerly $1,000, now $990.
                 *
                 * Because the bidAskAdjustment reverts to 1 in a few minutes, the new 3.03% buy premium is temporary: buy
                 * price will revert to the $990 mid soon - unless the new mid is egregiously low, in which case buyers should
                 * push it back up.  Eg, suppose the oracle gives us a glitchy price of $99.  Then new mid = $99, bidAskAdj =
                 * 10.303, buy price = $1,020, and the buy price will rapidly drop towards $99; but as it does so, users are
                 * incentivized to step in and buy, eventually pushing mid back up to the real-world ETH market price (eg
                 * $990).
                 *
                 * In cases like this, our bidAskAdj update has protected the system, by preventing users from getting any
                 * chance to buy at the bogus $99 price.
                 */
                if (adjustment > WAD) {
                    // max(1, old buy price / new mid price):
                    adjustment = WAD.wadMax(ls.ethUsdPrice.wadMulDivUp(adjustment, price));
                } else if (adjustment < WAD) {
                    // min(1, old sell price / new mid price):
                    adjustment = WAD.wadMin(ls.ethUsdPrice.wadMulDivDown(adjustment, price));
                }
            }
        }
    }

    /**
     * @notice Total amount of ETH in the pool (ie, in the contract).
     * @return pool ETH pool
     */
    function ethPool() public override view returns (uint pool) {
        pool = address(this).balance;
    }

    function fumTotalSupply() public override view returns (uint supply) {
        supply = fum.totalSupply();
    }

    /**
     * @notice The current bid/ask adjustment, equal to the stored value decayed over time towards its stable value, 1.  This
     * adjustment is intended as a measure of "how long-ETH recent user activity has been", so that we can slide price
     * accordingly: if recent activity was mostly long-ETH (`fund()` and `burn()`), raise FUM buy price/reduce USM sell price;
     * if recent activity was short-ETH (`defund()` and `mint()`), reduce FUM sell price/raise USM buy price.
     * @return adjustment The sliding-price bid/ask adjustment
     */
    function bidAskAdjustment() public override view returns (uint adjustment) {
        adjustment = loadState().bidAskAdjustment;      // Not just from storedState, b/c need to update it - see loadState()
    }

    function timeSystemWentUnderwater() public override view returns (uint timestamp) {
        timestamp = storedState.timeSystemWentUnderwater;
    }

    function isDuringPrefund() public override view returns (bool duringPrefund) {
        duringPrefund = block.timestamp < PREFUND_END_TIMESTAMP;
    }

    // ____________________ Public helper view functions (for functions above) ____________________

    /**
     * @return ls A `LoadedState` object packaging the system's current state: `ethUsdPrice`, `bidAskAdjustment`, etc (see
     * `storedState`), plus the ETH and USM balances.  `bidAskAdjustment` is also brought up to date, ie, decayed closer to 1
     * according to how much time has passed since it was stored: so if `bidAskAdjustment` was 2.0 five minutes ago, and
     * `BID_ASK_ADJUSTMENT_DECAY_PER_SECOND` corresponds to a half-life of 1 minute, `ls.bidAskAdjustment` is set to 1.03125
     * (see `bidAskAdjustment(storedTime, storedAdjustment, currentTime)`).
     */
    function loadState() public view returns (LoadedState memory ls) {
        ls.timeSystemWentUnderwater = storedState.timeSystemWentUnderwater;
        unchecked { ls.ethUsdPrice = storedState.ethUsdPrice * TRILLION; }  // Convert MILLION (1e6) format to WAD (1e18)
        unchecked { ls.oracleEthUsdPrice = storedState.oracleEthUsdPrice * TRILLION; }

        // Bring bidAskAdjustment up to the present - it gravitates towards 1 over time, so the stored value is obsolete:
        ls.bidAskAdjustmentTimestamp = block.timestamp;
        unchecked { ls.bidAskAdjustment = bidAskAdjustment(storedState.bidAskAdjustmentTimestamp,
                                                           storedState.bidAskAdjustment * TRILLION,
                                                           block.timestamp); }

        ls.ethPool = ethPool();
        ls.usmTotalSupply = totalSupply();
    }

    // ____________________ Public helper pure functions (for functions above) ____________________

    /**
     * @notice Calculate the amount of ETH in the buffer.
     * @return buffer ETH buffer
     */
    function ethBuffer(uint ethUsdPrice, uint ethInPool, uint usmSupply, bool roundUp)
        public override pure returns (int buffer)
    {
        // Reverse the input upOrDown, since we're using it for usmToEth(), which will be *subtracted* from ethInPool below:
        uint usmValueInEth = usmToEth(ethUsdPrice, usmSupply, !roundUp);    // Iff rounding the buffer up, round usmValue down
        require(ethUsdPrice <= uint(type(int).max) && usmValueInEth <= uint(type(int).max), "ethBuffer overflow/underflow");
        // After the previous line, no over/underflow should be possible here:
        unchecked { buffer = int(ethInPool) - int(usmValueInEth); }
    }

    /**
     * @notice Calculate debt ratio for a given eth to USM price: ratio of the outstanding USM (amount of USM in total supply),
     * to the current ETH pool value in USD (ETH qty * ETH/USD price).
     * @return ratio Debt ratio (or 0 if there's currently 0 ETH in the pool/price = 0: these should never happen after launch)
     */
    function debtRatio(uint ethUsdPrice, uint ethInPool, uint usmSupply) public override pure returns (uint ratio) {
        uint ethPoolValueInUsd = ethInPool.wadMulDown(ethUsdPrice);
        ratio = (usmSupply == 0 ? 0 : (ethPoolValueInUsd == 0 ? type(uint).max : usmSupply.wadDivUp(ethPoolValueInUsd)));
    }

    /**
     * @notice Convert ETH amount to USM using a ETH/USD price.
     * @param ethAmount The amount of ETH to convert
     * @return usmOut The amount of USM
     */
    function ethToUsm(uint ethUsdPrice, uint ethAmount, bool roundUp) public override pure returns (uint usmOut) {
        usmOut = ethAmount.wadMul(ethUsdPrice, roundUp);
    }

    /**
     * @notice Convert USM amount to ETH using a ETH/USD price.
     * @param usmAmount The amount of USM to convert
     * @return ethOut The amount of ETH
     */
    function usmToEth(uint ethUsdPrice, uint usmAmount, bool roundUp) public override pure returns (uint ethOut) {
        ethOut = usmAmount.wadDiv(ethUsdPrice, roundUp);
    }

    /**
     * @return price The ETH/USD price, adjusted by the `bidAskAdjustment` (if applicable) for the given buy/sell side.
     */
    function adjustedEthUsdPrice(IUSM.Side side, uint ethUsdPrice, uint adjustment) public override pure returns (uint price) {
        price = ethUsdPrice;

        // Apply the adjustment if (side == Buy and adj > 1), or (side == Sell and adj < 1):
        if (side == IUSM.Side.Buy ? (adjustment > WAD) : (adjustment < WAD)) {
            price = price.wadMul(adjustment, side == IUSM.Side.Buy);    // Round up iff side = buy
        }
    }

    /**
     * @notice Calculate the *marginal* price of USM (in ETH terms): that is, of the next unit, before the price start sliding.
     * @return price USM price in ETH terms
     */
    function usmPrice(IUSM.Side side, uint ethUsdPrice) public override pure returns (uint price) {
        price = usmToEth(ethUsdPrice, WAD, side == IUSM.Side.Buy);      // Round up iff side = buy
    }

    /**
     * @notice Calculate the *marginal* price of FUM (in ETH terms): that is, of the next unit, before the price starts rising.
     * @param usmEffectiveSupply should be either the actual current USM supply, or, when calculating the FUM *buy* price, the
     * return value of `usmSupplyForFumBuys()`.
     * @return price FUM price in ETH terms
     */
    function fumPrice(IUSM.Side side, uint ethUsdPrice, uint ethInPool, uint usmEffectiveSupply, uint fumSupply, bool prefund)
        public override pure returns (uint price)
    {
        if (prefund) {
            price = PREFUND_FUM_PRICE_IN_ETH;   // We're in the prefund period, so the price is just the prefund's "prix fixe"
        } else {
            // Using usmEffectiveSupply here, rather than just the raw actual supply, has the effect of bumping the FUM price
            // up to the minFumBuyPrice when needed (ie, when debt ratio > MAX_DEBT_RATIO):
            bool roundUp = (side == IUSM.Side.Buy);
            int buffer = ethBuffer(ethUsdPrice, ethInPool, usmEffectiveSupply, roundUp);
            price = (buffer <= 0 ? 0 : uint(buffer).wadDiv(fumSupply, roundUp));
        }
    }

    /**
     * @return timeSystemWentUnderwater_ The time at which we first detected the system was underwater (debt ratio >
     * `MAX_DEBT_RATIO`), based on the current oracle price and pool ETH and USM; or 0 if we're not currently underwater.
     * @return usmSupplyForFumBuys The current supply of USM *for purposes of calculating the FUM buy price,* and therefore
     * for `fumFromFund()`.  The "supply for FUM buys" is the *lesser* of the actual current USM supply, and the USM amount
     * that would make debt ratio = `MAX_DEBT_RATIO`.  Example:
     *
     * 1. Suppose the system currently contains 50 ETH at price $1,000 (total pool value: $50,000), with an actual USM supply
     *    of 30,000 USM.  Then debt ratio = 30,000 / $50,000 = 60%: < MAX 80%, so `usmSupplyForFumBuys` = 30,000.
     * 2. Now suppose ETH/USD halves to $500.  Then pool value halves to $25,000, and debt ratio doubles to 120%.  Now
     *    `usmSupplyForFumBuys` instead = 20,000: the USM quantity at which debt ratio would equal 80% (20,000 / $25,000).
     *    (Call this the "80% supply".)
     * 3. ...Except, we also gradually increase the supply over time while we remain underwater.  This has the effect of
     *    *reducing* the FUM buy price inferred from that supply (higher JacobUSM supply -> smaller buffer -> lower FUM price).
     *    The math we use gradually increases the supply from its initial "80% supply" value, where debt ratio =
     *    `MAX_DEBT_RATIO` (20,000 above), to a theoretical maximum "100% supply" value, where debt ratio = 100% (in the $500
     *    example above, this would be 25,000).  (Or the actual supply, whichever is lower: we never increase
     *    `usmSupplyForFumBuys` above `usmActualSupply`.)  The climb from the initial 80% supply (20,000) to the 100% supply
     *    (25,000) is at a rate that brings it "halfway closer per `minFumBuyPrice` half-life (eg, 1 day)": so three days after
     *    going underwater, the supply returned will be 25,000 - 0.5**3 * (25,000 - 20,000) = 24,375.
     */
    function checkIfUnderwater(uint usmActualSupply, uint ethPool_, uint ethUsdPrice, uint oldTimeUnderwater, uint currentTime)
        public override pure returns (uint timeSystemWentUnderwater_, uint usmSupplyForFumBuys, uint debtRatio_)
    {
        debtRatio_ = debtRatio(ethUsdPrice, ethPool_, usmActualSupply);
        if (debtRatio_ <= MAX_DEBT_RATIO) {            // We're not underwater, so leave timeSystemWentUnderwater_ as 0
            usmSupplyForFumBuys = usmActualSupply;     // When not underwater, USM supply for FUM buys is just actual supply
        } else {                                       // We're underwater
            // Set timeSystemWentUnderwater_ to currentTime, if it wasn't already set:
            timeSystemWentUnderwater_ = (oldTimeUnderwater != 0 ? oldTimeUnderwater : currentTime);

            // Calculate usmSupplyForFumBuys:
            uint maxEffectiveDebtRatio = debtRatio_.wadMin(WAD);    // min(actual debt ratio, 100%)
            uint decayFactor = MIN_FUM_BUY_PRICE_DECAY_PER_SECOND.wadPowInt(currentTime - timeSystemWentUnderwater_);
            uint effectiveDebtRatio = maxEffectiveDebtRatio - decayFactor.wadMulUp(maxEffectiveDebtRatio - MAX_DEBT_RATIO);
            usmSupplyForFumBuys = effectiveDebtRatio.wadMulDown(ethPool_.wadMulDown(ethUsdPrice));
        }
    }

    /**
     * @notice Returns the given stored `bidAskAdjustment` value, updated (decayed towards 1) to the current time.
     */
    function bidAskAdjustment(uint storedTime, uint storedAdjustment, uint currentTime) public pure returns (uint adjustment) {
        uint secsSinceStored = currentTime - storedTime;
        // ZERO_OUT_PERIOD here is important, so a long gap between ops doesn't waste a lot of gas calculating the ~0 decay:
        uint decayFactor = (secsSinceStored >= BID_ASK_ADJUSTMENT_ZERO_OUT_PERIOD ? 0 :
                            BID_ASK_ADJUSTMENT_DECAY_PER_SECOND.wadPowInt(secsSinceStored));
        // Here we use the idea that for any b and 0 <= p <= 1, we can crudely approximate b**p by 1 + (b-1)p = 1 + bp - p.
        // Eg: 0.6**0.5 pulls 0.6 "about halfway" to 1 (0.8); 0.6**0.25 pulls 0.6 "about 3/4 of the way" to 1 (0.9).
        // So b**p =~ b + (1-p)(1-b) = b + 1 - b - p + bp = 1 + bp - p.
        // (Don't calculate it as 1 + (b-1)p because we're using uints, b-1 can be negative!)
        adjustment = WAD + storedAdjustment.wadMulDown(decayFactor) - decayFactor;
    }

    /**
     * @notice How much USM a minter currently gets back for `ethIn` ETH, accounting for `bidAskAdjustment` and sliding prices.
     * @param ethIn The amount of ETH passed to `mint()`
     * @return usmOut The amount of USM to receive in exchange
     */
