    function getBondGroup(uint256 bondGroupID)
        public
        override
        view
        returns (bytes32[] memory bondIDs, uint256 maturity)
    {
        require(bondGroupID < nextBondGroupID, "the bond group does not exist");
        BondGroup memory bondGroup = _bondGroupList[bondGroupID];
        bondIDs = bondGroup.bondIDs;
        maturity = bondGroup.maturity;
    }
