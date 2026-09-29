    function claim(
        address claimer,
        uint128[] calldata tierIds,
        address recipient
    )
        external
        override
        whenNotPaused
        nonReentrant
        returns (uint256[] memory)
    {
        require(
            msg.sender == claimer,
            "Sender is not claimer"
        );
        return _claimBatch(claimer, tierIds, recipient);
    }
