    function beforeLdaTransfer(
        address from,
        address to,
        uint128 tierId
    )
        external
        override
        nonReentrant
    {
        require(
            msg.sender == address(LDA),
            "Sender is not the LDA contract"
        );
        if (from != address(0)) {
            _settleUcr(tierId, from);
        }
        if (to != address(0)) {
            _settleUcr(tierId, to);
        }
    }
