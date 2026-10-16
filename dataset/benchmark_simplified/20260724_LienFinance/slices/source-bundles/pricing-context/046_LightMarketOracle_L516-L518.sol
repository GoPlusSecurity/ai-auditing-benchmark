    function getPrice(uint256 id) external override returns (uint256) {
        return _activeOracle().getPrice(id);
    }
