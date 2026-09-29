    function _checkProver(
        address _addr,
        uint256 _proposalAge
    )
        private
        view
        returns (bool whitelistEnabled_)
    {
        if (address(_proverWhitelist) == address(0)) return false;

        (bool isWhitelisted, uint256 proverCount) = _proverWhitelist.isProverWhitelisted(_addr);
        if (proverCount == 0) return false;

        if (!isWhitelisted) {
            require(_proposalAge > uint256(_permissionlessProvingDelay), ProverNotWhitelisted());
        }
        return true;
    }
