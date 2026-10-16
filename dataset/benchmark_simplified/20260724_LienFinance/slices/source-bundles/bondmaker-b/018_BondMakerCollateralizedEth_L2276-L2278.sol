    function _assertBeforeMaturity(uint256 maturity) internal view {
        require(_getBlockTimestampSec() < maturity, "the maturity has already expired");
    }
