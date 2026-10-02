    function _update(address from, address to, uint256 amount) internal override {
        if (from == address(0) || to == address(0)) {
            super._update(from, to, amount);
            return;
        }

        if (inFee) {
            super._update(from, to, amount);
            return;
        }

        bool isBuy = isAMMPair[from];
        bool isSell = isAMMPair[to];
        bool isTransfer = !isBuy && !isSell;

        if (isBuy && buyWhitelistEnabled) {
            require(isBuyWhitelist[to], "not in buy whitelist");
        }

        if (isBuy || isSell) {
            if (isBuySellFeeExempt[from] || isBuySellFeeExempt[to]) {
                super._update(from, to, amount);
                return;
            }
        }

        if (isTransfer) {
            if (isTransferFeeExempt[from] || isTransferFeeExempt[to]) {
                super._update(from, to, amount);
                return;
            }
        }

        if (isBuy) {
            _takeBuyFee(from, to, amount);
        } else if (isSell) {
            _takeSellFee(from, to, amount);
        } else {
            _takeTransferFee(from, to, amount);
        }
    }
