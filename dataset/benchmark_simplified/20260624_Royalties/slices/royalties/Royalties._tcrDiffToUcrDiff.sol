    function _tcrDiffToUcrDiff(
        uint256 tcrDiff,
        uint256 proRataOwnership
    )
        internal
        pure
        returns (uint256)
    {
        return tcrDiff * proRataOwnership / PRO_RATA_BASE;
    }
