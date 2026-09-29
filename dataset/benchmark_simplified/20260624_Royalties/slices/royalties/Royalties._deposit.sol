    function _deposit(
        address depositor,
        uint128 tierId,
        uint256 depositAmount
    )
        internal
    {
        require(
            isTierInitialized(tierId),
            "Tier not initialized for deposit"
        );
        require(
            depositAmount >= _MINIMUM_DEPOSIT_AMOUNT_,
            "Deposit amount below minimum"
        );

        // Increment and get deposit ID.
        uint256 depositId = ++_NUM_DEPOSITS_[tierId];

        // Calculate new TCR.
        TcrRecord storage lastTcr = _TCR_[tierId][depositId - 1];
        uint256 newTcr = lastTcr.value + depositAmount;

        // Add TCR record.
        _TCR_[tierId][depositId] = TcrRecord({
            value: newTcr.toUint128(),
            timestamp: block.timestamp.toUint128()
        });

        // Make ERC-20 transfer to the contract.
        PAYMENT_ERC20.safeTransferFrom(depositor, address(this), depositAmount);

        emit Deposited(tierId, depositId, depositor, depositAmount);
    }
