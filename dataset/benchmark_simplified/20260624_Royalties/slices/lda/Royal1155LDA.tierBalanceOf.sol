    function tierBalanceOf(
        uint128 tierId,
        address owner
    )
        external
        view
        override
        returns (uint256)
    {
        return _BALANCES_[tierId][owner];
    }
