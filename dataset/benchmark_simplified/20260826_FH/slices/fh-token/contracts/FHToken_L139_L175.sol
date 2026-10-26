    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        if (sender == address(0)) revert TransferFromZero();
        if (recipient == address(0)) revert TransferToZero();

        uint256 fromBalance = _balances[sender];
        if (fromBalance < amount) {
            revert ERC20InsufficientBalance(sender, fromBalance, amount);
        }

        _balances[sender] = _balances[sender].sub(amount);

        if (recipient == address(0)) {
            unchecked {
                _totalSupply -= amount;
            }
        }

        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

    function _mint(address account, uint256 amount) internal virtual {
        if (account == address(0)) revert TransferToZero();

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual {
        if (account == address(0)) revert TransferFromZero();

        _balances[account] = _balances[account].sub(amount);
        _balances[address(0xdead)] = _balances[address(0xdead)].add(amount);
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0xdead), amount);
    }
