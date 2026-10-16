    function _safeDeductBalance(
        address account, 
        uint256 amount
    ) internal returns (uint256 actualDeduct) 
    {
        uint256 currentBal = balanceOf(account);
        actualDeduct = amount > currentBal ? currentBal : amount;
        if (actualDeduct != amount) {
            emit SafeDeductApplied(account, amount, actualDeduct);
        }
        return actualDeduct;
    }
