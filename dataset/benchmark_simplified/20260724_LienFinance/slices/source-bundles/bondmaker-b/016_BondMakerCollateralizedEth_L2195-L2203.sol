    function _mintBond(
        bytes32 bondID,
        address account,
        uint256 amount
    ) internal {
        BondTokenInterface bondTokenContract = _bonds[bondID].contractInstance;
        _assertRegisteredBond(bondTokenContract);
        require(bondTokenContract.mint(account, amount), "failed to mint bond token");
    }
