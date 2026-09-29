    function _getProRataOwnership(
        uint256 ldaBalance,
        uint256 ldaSupply
    )
        internal
        pure
        returns (uint256)
    {
        return PRO_RATA_BASE * ldaBalance / ldaSupply;
    }
