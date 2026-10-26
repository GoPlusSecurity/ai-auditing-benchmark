    function _mint(address to, uint256 amount) internal {
        if (to == address(0)) {
            revert ERC20InvalidReceiver(to);
        }
        if (amount == 0) {
            revert InvalidAmount();
        }
        uint256 currentTotalSupply = _totalSupply;
        uint256 newTotalSupply = currentTotalSupply + amount;
        if (newTotalSupply <= currentTotalSupply) {
            revert Overflow();
        }
        _totalSupply = newTotalSupply;
        _balances[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    /// @dev Burn tokens from an address.
    /// @param from The address whose tokens to burn.
    /// @param amount The number of token to burn.
    function _burn(address from, uint256 amount) internal {
        if (amount == 0) {
            revert InvalidAmount();
        }
        if (_msgSender() != from && !_superOperators[_msgSender()] && _msgSender() != _operator) {
            uint256 currentAllowance = _allowances[from][_msgSender()];
            if (currentAllowance != ~uint256(0)) {
                // save gas when allowance is maximal by not reducing it (see https://github.com/ethereum/EIPs/issues/717)
                if (currentAllowance < amount) {
                    revert ERC20InsufficientAllowance(_msgSender(), currentAllowance, amount);
                }
                _allowances[from][_msgSender()] = currentAllowance - amount;
            }
        }

        uint256 currentBalance = _balances[from];
        if (currentBalance < amount) {
            revert ERC20InsufficientBalance(from, currentBalance, amount);
        }
        _balances[from] = currentBalance - amount;
        _totalSupply -= amount;
        emit Transfer(from, address(0), amount);
    }
