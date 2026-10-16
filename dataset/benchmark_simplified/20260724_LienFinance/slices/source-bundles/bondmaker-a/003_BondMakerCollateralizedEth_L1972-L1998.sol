    function registerNewBondGroup(bytes32[] calldata bondIDs, uint256 maturity)
        external
        virtual
        override
        returns (uint256 bondGroupID)
    {
        _assertBondGroup(bondIDs, maturity);

        (, , uint64 sbtStrikePrice, ) = getBond(bondIDs[0]);
        for (uint256 i = 1; i < bondIDs.length; i++) {
            (, , uint64 strikePrice, ) = getBond(bondIDs[i]);
            require(
                strikePrice == 0,
                "except the first bond must not be pure SBT"
            );
        }

        // Get and increment next bond group ID
        bondGroupID = _nextBondGroupID;
        _nextBondGroupID = _nextBondGroupID.add(1);

        _bondGroupList[bondGroupID] = BondGroup(bondIDs, maturity);

        emit LogNewBondGroup(bondGroupID, maturity, sbtStrikePrice, bondIDs);

        return bondGroupID;
    }
