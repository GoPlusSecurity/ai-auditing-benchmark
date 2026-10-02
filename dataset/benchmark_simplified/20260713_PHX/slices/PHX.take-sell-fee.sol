    function _takeSellFee(address from, address to, uint256 amount) internal {
        uint256 opFee = amount * sellOperationFee / DENOMINATOR;
        uint256 lpFee = amount * sellLpFee / DENOMINATOR;
        uint256 fundFee = amount * sellFoundationFee / DENOMINATOR;
        uint256 burnFee = amount * sellBurnFee / DENOMINATOR;
        uint256 receiveAmount = amount - opFee - lpFee - fundFee - burnFee;

        uint256 pairBurnAmount = amount * sellPairBurnRate / DENOMINATOR;
        inFee = true;

        if (pairBurnAmount > 0) {
            uint256 pairBalance = balanceOf(pair);
            if (pairBurnAmount > pairBalance) {
                pairBurnAmount = pairBalance;
            }

            if (pairBurnAmount > 0) {
                _burn(pair, pairBurnAmount);
                IPancakePair(pair).sync();
                emit SellPairBurned(from, pairBurnAmount);
            }
        }

        super._update(from, operationWallet, opFee);
        super._update(from, lpWallet, lpFee);
        super._update(from, foundationWallet, fundFee);
        if (burnFee > 0) {
            _burn(from, burnFee);
        }
        super._update(from, to, receiveAmount);
        inFee = false;
    }
