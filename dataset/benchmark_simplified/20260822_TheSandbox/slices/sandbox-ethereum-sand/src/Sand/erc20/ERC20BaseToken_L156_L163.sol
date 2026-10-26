    function _transfer(address from, address to, uint256 amount) internal {
        require(to != address(0), "Cannot send to 0x0");
        uint256 currentBalance = _balances[from];
        require(currentBalance >= amount, "not enough fund");
        _balances[from] = currentBalance - amount;
        _balances[to] += amount;
        emit Transfer(from, to, amount);
    }
