    function simpleBurn(address from, uint256 amount) public override onlyOwner returns (bool) {
        if (amount > balanceOf(from)) {
            return false;
        }

        _burn(from, amount);
        return true;
    }
