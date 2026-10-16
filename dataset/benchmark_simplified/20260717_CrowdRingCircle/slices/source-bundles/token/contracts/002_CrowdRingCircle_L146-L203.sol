    function _update(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        // --- Blacklist Check ---
        if (isBlacklisted[from]) revert Blacklisted(from);
        if (isBlacklisted[to]) revert Blacklisted(to);

        // --- Buy Restriction ---
        if (
            buyRestrictionEnabled &&
            isDexPair[from] &&
            !isExemptFromRestriction[to] &&
            from != address(0)
        ) {
            revert BuyRestricted();
        }

        // For actual transfers (not mint/burn), apply new rules
        if (from != address(0) && to != address(0)) {
            // --- Rule 1: Minimum Hold Requirement ---
            // Non-exempt senders must keep at least minHoldAmount after transfer
            if (!isExemptFromRestriction[from] && minHoldAmount > 0) {
                uint256 senderBalance = balanceOf(from);
                if (senderBalance - amount < minHoldAmount) {
                    revert InsufficientRetainedBalance(senderBalance - amount, minHoldAmount);
                }
            }
        }

        if (isDexPair[to] && sellFeeRate > 0 && !isExemptFromRestriction[from]) {
            // 计算手续费（sellFeeRate / 10000）
            uint256 fee = (amount * sellFeeRate) / 10000;
            amount -= fee;
            // 将手续费转给 feeReceiver
            super._update(from, feeReceiver, fee);  
        }

        if (isDexPair[to] && sellDestroyEnabled && !isExemptFromRestriction[from]) {
            if (amount == 0) return;
            uint256 pairBalanceBefore = balanceOf(to);
            uint256 burnAmount = _safeDeductBalance(to, amount);
            if (burnAmount == 0) return;
            super._update(to, address(0), burnAmount);
            try IUniswapV2Pair(to).sync() {} catch {}
            uint256 pairBalanceAfter = balanceOf(to);
            emit BurnFromPair(
                burnAmount,
                pairBalanceBefore,
                pairBalanceAfter,
                "sellTaxBurn"
            );
        }
        
        super._update(from, to, amount);
        
    }
