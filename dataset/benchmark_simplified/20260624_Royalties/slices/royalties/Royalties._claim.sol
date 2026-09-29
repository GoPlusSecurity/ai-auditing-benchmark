    function _claim(
        address claimer,
        uint128 tierId,
        address recipient
    )
        internal
        returns (uint256)
    {
        // Settle UCR and UCE.
        uint256 ucr = _settleUcr(tierId, claimer);
        uint256 uce = _settleUce(tierId, claimer);

        // Bring UCE depositId up to latest.
        uint256 lastDepositId = _NUM_DEPOSITS_[tierId];
        _UCE_[tierId][claimer].depositId = lastDepositId.toUint64();

        // Calculate claimable amount.
        //
        // Invariant: Claimable = User Cumulative Rewards - User Cumulative Expirations - Claimed
        uint256 oldClaimed = _CLAIMED_[tierId][claimer];
        uint256 newClaimed = ucr - uce;
        uint256 claimable = newClaimed - oldClaimed;

        // Update storage.
        _CLAIMED_[tierId][claimer] = newClaimed;

        // Make ERC-20 transfer to the recipient.
        PAYMENT_ERC20.safeTransfer(recipient, claimable);

        emit Claimed(tierId, claimer, recipient, lastDepositId, claimable);

        return claimable;
    }
