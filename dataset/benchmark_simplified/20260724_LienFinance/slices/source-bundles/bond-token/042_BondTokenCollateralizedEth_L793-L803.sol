    function mint(address account, uint256 amount)
        public
        virtual
        override
        onlyOwner
        returns (bool success)
    {
        require(!_isExpired(), "this token contract has expired");
        _mint(account, amount);
        return true;
    }
