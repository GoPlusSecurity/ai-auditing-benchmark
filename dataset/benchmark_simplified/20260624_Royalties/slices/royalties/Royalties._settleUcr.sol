    function _settleUcr(
        uint128 tierId,
        address account
    )
        internal
        returns (uint256)
    {
        uint256 lastUcrId = _NUM_UCR_RECORDS_[tierId][account];
        UcrRecord memory lastUcrRecord = _UCR_[tierId][account][lastUcrId];
        uint128 lastSettledDepositId = lastUcrRecord.depositId;
        uint256 lastDepositId = _NUM_DEPOSITS_[tierId];

        // Calculate the change in UCR and the new UCR.
        uint256 ldaBalance = LDA.tierBalanceOf(tierId, account);

        // If the last TCR entry is zero, then there have never been any (non-zero) deposits to
        // this tier, and the change in UCR is zero.
        uint256 ucrDiff = 0;

        // If the last TCR entry is not zero, calculate the change in UCR.
        TcrRecord memory lastTcrRecord = _TCR_[tierId][lastDepositId];
        if (lastTcrRecord.value != 0) {
            // Calculate the change in TCR between the last settled and last deposit IDs.
            TcrRecord memory lastSettledTcrRecord = _TCR_[tierId][lastSettledDepositId];
            uint256 tcrDiff = lastTcrRecord.value - lastSettledTcrRecord.value;

            // Get the pro rata ownership in base units.
            //
            // IMPORTANT - Proof that division by zero will not occur:
            //
            //     This code path may only run if there have been non-zero deposits.
            //     Existence of deposits implies that the tier has been initialized.
            //     Tier initialized implies that ldaSupply is non-zero.
            uint256 ldaSupply = _TIERS_[tierId].supply;
            uint256 proRataOwnership = _getProRataOwnership(ldaBalance, ldaSupply);

            ucrDiff = _tcrDiffToUcrDiff(tcrDiff, proRataOwnership);
        }

        uint256 newUcrValue = lastUcrRecord.value + ucrDiff;

        // Add the new UCR record.
        unchecked {
            uint256 newUcrId = lastUcrId + 1;
            _NUM_UCR_RECORDS_[tierId][account] = newUcrId;
            _UCR_[tierId][account][newUcrId] = UcrRecord({
                depositId: lastDepositId.toUint64(),
                ldaBalance: ldaBalance.toUint64(),
                value: newUcrValue.toUint128()
            });
        }

        // Return the current UCR value.
        return newUcrValue;
    }
