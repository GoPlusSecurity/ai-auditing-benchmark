    function _getBond(BondMakerInterface bondMaker, bytes32 bondID)
        internal
        view
        returns (
            ERC20 bondToken,
            uint256 maturity,
            uint256 sbtStrikePrice,
            bytes32 fnMapID
        )
    {
        address bondTokenAddress;
        (bondTokenAddress, maturity, sbtStrikePrice, fnMapID) = bondMaker
            .getBond(bondID);

        // Revert if `bondTokenAddress` is zero.
        bondToken = ERC20(bondTokenAddress);
    }
