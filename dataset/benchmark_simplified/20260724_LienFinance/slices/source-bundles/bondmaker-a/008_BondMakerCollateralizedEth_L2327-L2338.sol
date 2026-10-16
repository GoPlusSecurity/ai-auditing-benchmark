    function _burnBond(
        bytes32 bondID,
        address account,
        uint256 amount
    ) internal {
        BondTokenInterface bondTokenContract = _bonds[bondID].contractInstance;
        _assertRegisteredBond(bondTokenContract);
        require(
            bondTokenContract.simpleBurn(account, amount),
            "failed to burn bond token"
        );
    }
