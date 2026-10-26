    function _update(address from, address to, uint256 amount) internal override {
        // Step 1: Mint / Burn — passthrough
        if (from == address(0) || to == address(0)) {
            super._update(from, to, amount);
            return;
        }

        // Step 2: Zero amount
        if (amount == 0) {
            super._update(from, to, 0);
            return;
        }

        // Step 3: Internal swap / self-transfer
        if (inSwap || from == address(this) || to == address(this)) {
            super._update(from, to, amount);
            return;
        }

        // Step 4: Released MOKE restriction — BEFORE exempt (#2 fix)
        // Released MOKE can only go to isReleasedMokeHandler (#3 fix)
        if (releasedMokeBalance[from] > 0) {
            uint256 bal = balanceOf(from);
            uint256 released = releasedMokeBalance[from];
            uint256 freeBalance = bal > released ? bal - released : 0;

            if (isReleasedMokeHandler[to] || isWhitelisted[to]) {
                if (amount > freeBalance) {
                    uint256 releasedUsed = amount - freeBalance;
                    releasedMokeBalance[from] -= releasedUsed;
                    emit ReleasedBalanceReduced(from, releasedUsed);
                }
            } else {
                require(amount <= freeBalance, "Released MOKE: handler only");
            }
        }

        // Step 5: Tax exempt — passthrough
        bool exempt = isExcludedFromTax[from] || isExcludedFromTax[to];
        if (exempt) {
            super._update(from, to, amount);
            return;
        }

        // Step 6: LP removal burn detection (#5)
        // Only for main MOKE/WBNB pair. Handles both token orderings.
        if (from == pancakePair && lpRemovalBurnEnabled) {
            uint256 wethBal = IERC20(weth).balanceOf(pancakePair);
            (uint112 r0, uint112 r1,) = IPancakePairT(pancakePair).getReserves();
            uint256 wethReserve = isWethToken0 ? uint256(r0) : uint256(r1);
            uint256 mokeReserve = isWethToken0 ? uint256(r1) : uint256(r0);

            uint256 maxMokeFromBuy = 0;
            if (wethBal > wethReserve && mokeReserve > 0 && wethReserve > 0) {
                maxMokeFromBuy = (wethBal - wethReserve) * mokeReserve / wethReserve;
            }

            if (amount > maxMokeFromBuy) {
                super._update(from, address(0xdead), amount);
                emit LPRemovalBurn(to, amount);
                return;
            }
        }

        // Step 7: Market pair detection — trading check & tax
        bool isPairInvolved = _isMarketPair(from) || _isMarketPair(to);

        if (isPairInvolved && lpDividendPool != address(0)) {
            _syncLPDividend(from, to);
        }

        if (!tradingEnabled && isPairInvolved) {
            if (_isMarketPair(from)) {
                require(isWhitelisted[to], "Trading not enabled");
            }
            if (_isMarketPair(to)) {
                require(isWhitelisted[from], "Trading not enabled");
            }
        }

        if (isPairInvolved) {
            if (_isMarketPair(to)) {
                _processTaxes();
            }

            uint256 totalTaxRate = lpDivRate + nftDivRate + marketingRate;
            uint256 taxAmount = amount * totalTaxRate / BASIS_POINTS;

            if (taxAmount > 0) {
                uint256 lpAmount = amount * lpDivRate / BASIS_POINTS;
                uint256 nftAmount = amount * nftDivRate / BASIS_POINTS;
                uint256 mktAmount = taxAmount - lpAmount - nftAmount;

                super._update(from, address(this), taxAmount);

                accumulatedLpTax += lpAmount;
                accumulatedNftTax += nftAmount;
                accumulatedMarketingTax += mktAmount;

                emit TaxCollected(from, to, lpAmount, nftAmount, mktAmount);
                amount -= taxAmount;
            }
        }

        super._update(from, to, amount);
    }

    // ============ Market Pair Detection (Multi-DEX) ============

    function _isMarketPair(address target) internal view returns (bool) {
        if (isMarketPair[target]) return true;
        if (target.code.length == 0) return false;

        try IPancakePairT(target).token0() returns (address t0) {
            if (t0 == address(0)) return false;
            try IPancakePairT(target).token1() returns (address t1) {
                if (t1 == address(0)) return false;
                return (t0 == address(this) || t1 == address(this));
            } catch {
                return false;
            }
        } catch {
            return false;
        }
    }

    // ============ LP Dividend Sync (try/catch — never blocks transfers) ============

    function _syncLPDividend(address from, address to) internal {
        if (!_isMarketPair(from)) {
            try IMokeLPDividend(lpDividendPool).syncUserLP(from) {} catch {}
        }
        if (!_isMarketPair(to)) {
            try IMokeLPDividend(lpDividendPool).syncUserLP(to) {} catch {}
        }
    }

    // ============ Tax Processing (via SwapReceiver relay) ============

    function _processTaxes() internal {
        uint256 totalTax = accumulatedLpTax + accumulatedNftTax + accumulatedMarketingTax;
        if (totalTax < swapThreshold) return;
        if (address(router) == address(0)) return;

        uint256 lpToProcess = accumulatedLpTax;
        uint256 nftToProcess = accumulatedNftTax;
        uint256 mktToProcess = accumulatedMarketingTax;

        if (totalTax > maxSwapAmount) {
            uint256 ratio = maxSwapAmount * 1e18 / totalTax;
            lpToProcess = accumulatedLpTax * ratio / 1e18;
            nftToProcess = accumulatedNftTax * ratio / 1e18;
            mktToProcess = maxSwapAmount - lpToProcess - nftToProcess;
        }

        uint256 tokensToSwap = lpToProcess + nftToProcess + mktToProcess;
        if (tokensToSwap == 0) return;

        accumulatedLpTax -= lpToProcess;
        accumulatedNftTax -= nftToProcess;
        accumulatedMarketingTax -= mktToProcess;

        uint256 bnbReceived = _swapTokensForBNB(tokensToSwap);
        if (bnbReceived == 0) {
            accumulatedLpTax += lpToProcess;
            accumulatedNftTax += nftToProcess;
            accumulatedMarketingTax += mktToProcess;
            return;
        }

        emit TaxSwapped(tokensToSwap, bnbReceived);

        uint256 lpBNB = bnbReceived * lpToProcess / tokensToSwap;
        uint256 nftBNB = bnbReceived * nftToProcess / tokensToSwap;
        uint256 mktBNB = bnbReceived - lpBNB - nftBNB;

        _distributeTaxBNB(lpBNB, nftBNB, mktBNB);
    }

    /**
     * @dev Swap MOKE -> BNB via SwapReceiver relay.
     *      Router sends ETH to SwapReceiver, then we sweep it back.
     */
    function _swapTokensForBNB(uint256 tokenAmount) internal swapping returns (uint256) {
        if (tokenAmount == 0) return 0;

        _approve(address(this), address(router), tokenAmount);

        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = router.WETH();

        address receiver = address(swapReceiver);
        uint256 receiverBalBefore = receiver.balance;
        uint256 minOut = _getSwapMinOutput(tokenAmount);

        try router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount, minOut, path, receiver, block.timestamp + 300
        ) {
            uint256 bnbReceived = receiver.balance - receiverBalBefore;
            if (bnbReceived > 0) {
                swapReceiver.sweepETH(address(this));
            }
            return bnbReceived;
        } catch {
            return 0;
        }
    }

    function _getSwapMinOutput(uint256 tokenAmount) internal view returns (uint256) {
        if (pancakePair == address(0)) return 0;

        try IPancakePairT(pancakePair).getReserves() returns (uint112 r0, uint112 r1, uint32) {
            address t0 = IPancakePairT(pancakePair).token0();
            uint256 reserveToken;
            uint256 reserveBNB;
            if (t0 == address(this)) { reserveToken = r0; reserveBNB = r1; }
            else { reserveToken = r1; reserveBNB = r0; }
            if (reserveToken == 0 || reserveBNB == 0) return 0;

            uint256 amountInWithFee = tokenAmount * 997;
            uint256 expectedOut = amountInWithFee * reserveBNB / (reserveToken * 1000 + amountInWithFee);
            return expectedOut * (BASIS_POINTS - swapSlippageBps) / BASIS_POINTS;
        } catch {
            return 0;
        }
    }

    function _distributeTaxBNB(uint256 lpBNB, uint256 nftBNB, uint256 mktBNB) internal {
        if (lpBNB > 0 && lpDividendPool != address(0)) {
            (bool sent,) = payable(lpDividendPool).call{value: lpBNB}("");
            if (!sent) { pendingLpBNB += lpBNB; }
        } else if (lpBNB > 0) {
            pendingLpBNB += lpBNB;
        }

        if (nftBNB > 0 && nftDividendPool != address(0)) {
            (bool sent,) = payable(nftDividendPool).call{value: nftBNB}("");
            if (!sent) { pendingNftBNB += nftBNB; }
        } else if (nftBNB > 0) {
            pendingNftBNB += nftBNB;
        }

        if (mktBNB > 0) {
            (bool sent,) = payable(marketingWallet).call{value: mktBNB}("");
            if (!sent) { pendingMarketingBNB += mktBNB; }
        }

        emit TaxDistributed(lpBNB, nftBNB, mktBNB);
    }

