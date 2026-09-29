    function deposit(
        address depositor,
        uint128 tierId,
        uint256 amount
    )
        external
        override
        whenNotPaused
        nonReentrant
    {
        require(
            msg.sender == depositor,
            "Sender is not depositor"
        );
        _deposit(depositor, tierId, amount);
    }
