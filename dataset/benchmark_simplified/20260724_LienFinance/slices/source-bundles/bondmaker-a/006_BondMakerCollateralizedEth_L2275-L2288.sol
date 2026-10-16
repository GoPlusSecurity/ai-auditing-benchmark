    function getBondGroup(uint256 bondGroupID)
        public
        view
        override
        returns (bytes32[] memory bondIDs, uint256 maturity)
    {
        require(
            bondGroupID < _nextBondGroupID,
            "the bond group does not exist"
        );
        BondGroup memory bondGroup = _bondGroupList[bondGroupID];
        bondIDs = bondGroup.bondIDs;
        maturity = bondGroup.maturity;
    }
