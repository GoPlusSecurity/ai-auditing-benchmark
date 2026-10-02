    function _transferRoot(address from, address to, uint256 amount) private {
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        if(to == address(0)) totalSupply -= amount;
        emit Transfer(from, to, amount);
    }

    function _transfer(address from, address to, uint256 amount) private {
        require(from != address(0), 'from error');
        require(to != address(0), 'to error');

        // maybe is remove or buy
        if(from == WBNB_Token_LP_Address) {
            if(_isRemove(amount) > 0) {
                // is remove.
                _transferRoot(from, address(0), amount);
            }else {
                // is buy.
                // must is Core address.
                require(to == CoreAddress, 'not buy');
                _transferRoot(from, to, amount);
            }
        }else {
            // add or sell. or normal transfer.
            _transferRoot(from, to, amount);
        }

        // price defl
        _priceDeflPool(from, to);
        // defl
        _deflPool(from, to);
        // Bound
        _bound(from, to, amount);
    }
