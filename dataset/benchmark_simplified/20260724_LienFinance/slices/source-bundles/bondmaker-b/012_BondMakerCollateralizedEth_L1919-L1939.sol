    function registerNewBondGroup(bytes32[] calldata bondIDs, uint256 maturity)
        external
        virtual
        override
        returns (uint256 bondGroupID)
    {
        _assertBondGroup(bondIDs, maturity);

        (, , uint64 sbtStrikePrice, ) = getBond(bondIDs[0]);
        require(sbtStrikePrice != 0, "the first bond must be SBT");

        // Get and increment next bond group ID
        bondGroupID = nextBondGroupID;
        nextBondGroupID = nextBondGroupID.add(1);

        _bondGroupList[bondGroupID] = BondGroup(bondIDs, maturity);

        emit LogNewBondGroup(bondGroupID, maturity, sbtStrikePrice, bondIDs);

        return bondGroupID;
    }
