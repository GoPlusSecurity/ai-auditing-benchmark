    function _settleUce(
        uint128 tierId,
        address account
    )
        internal
        returns (uint256)
    {
        UceRecord memory uceRecord = _UCE_[tierId][account];

        UceSettlementLocals memory locals = UceSettlementLocals({
            i: uceRecord.depositId, // a.k.a. lastSettledDepositId,
            j: _NUM_EXPIRED_DEPOSITS_[tierId], // a.k.a. lastExpiredDepositId,
            x: 0,
            xUcrId: 0,
            y: 0,
            yUcrId: 0,
            p1: 0,
            p2: 0
        });

        // There are two cases:
        //
        //   “healthy”  : lastSettledDepositId >= lastExpiredDepositId
        //                No deposit has expired that was not previously claimed by the user,
        //                in other words, none of the user's claims have expired.
        //
        //   “unhealthy”: lastSettledDepositId < lastExpiredDepositId
        //                At least one of the user's claims has expired.
        //
        // Short-circuit in the healthy case.
        if (locals.i >= locals.j) {
            // Return the current UCE value.
            return uceRecord.value;
        }

        // Find change in UCR between lastSettledDepositId and lastExpiredDepositId deposit IDs.
        // This result is the change in UCE (i.e. the newly expired amount).
        //
        // Since UCR records do not necessarily exist for every deposit ID, we may have to
        // interpolate between UCR records to calculate the expired amount.
        //
        // Example:
        //
        //   deposit ID       0    1    2    3    4    5    6
        //
        //   TCR              0    10   20   40   60   80   100
        //
        //   User pro-rata              10%            20%
        //
        //   UCR              0         0              6
        //   -> interpolated       0         2    4         10
        //
        // Define the following references to deposit IDs:
        //
        //   i = lastSettledDepositId
        //   j = lastExpiredDepositId
        //   x = max ucr.depositId such that ucr.depositId <= i (or zero, if no ucr records)
        //   y = max ucr.depositId such that ucr.depositId < j (or zero, if no ucr records)
        //
        // We have the following constraints which follow logically from the above definitions:
        //
        //   x <= i < j
        //   x <= y < j
        //   0 < j <= NUM_DEPOSITS  (i.e. j refers to an existing deposit)
        //
        // There are two cases:
        //
        //   Case x == y:
        //
        //     Then the user's pro-rata share is a constant `p` during the [i, j] period, and
        //       uceDiff = (TCR[j] - TCR[i]) * p
        //
        //   Case x != y:
        //
        //     Then x <= i <= y < j, and
        //     The user's pro-rata share is a constant `p1` during the [x, i] period, and
        //     The user's pro-rata share is a constant `p2` during the [y, j] period, and
        //       uceDiff = (UCR[y] - UCR[x])
        //               - (TCR[i] - TCR[x]) * p1
        //               + (TCR[j] - TCR[y]) * p2
        //
        //   Where UCR[x] denoes the value of the UCR record with deposit ID x,
        //     and TCR[x] denoes the value of the TCR record with deposit ID x.

        locals.xUcrId = uceRecord.ucrId;
        UcrRecord memory xUcr = _UCR_[tierId][account][uceRecord.ucrId];
        locals.x = xUcr.depositId;

        // Find yUcrId and y, or validate and use the provided hint.
        {
            (uint256 yUcrId, uint256 y) = _getY(
                tierId,
                account,
                locals.j,
                uceRecord.ucrId,
                0,
                false
            );
            locals.yUcrId = yUcrId;
            locals.y = y;
        }

        // TODO: Remove these sanity checks later.
        {
            assert(locals.x <= locals.i && locals.i < locals.j);
            assert(locals.x <= locals.y && locals.y < locals.j);
            assert(0 < locals.j && locals.j <= _NUM_DEPOSITS_[tierId]);
        }

        uint256 ldaSupply = _TIERS_[tierId].supply;

        // Calculate the change in UCE (i.e. the newly expired amount).
        uint256 uceDiff;
        if (locals.x == locals.y) {
            {
                uint256 ldaBalance1 = _getLdaBalanceAfterUcr(tierId, account, locals.yUcrId);
                locals.p1 = _getProRataOwnership(ldaBalance1, ldaSupply);
            }
            uint256 tcrDiff = _TCR_[tierId][locals.j].value - _TCR_[tierId][locals.i].value;
            uceDiff = _tcrDiffToUcrDiff(tcrDiff, locals.p1); // uceDiff = ucrDiff
        } else {
            // uceDiff = (UCR[y] - UCR[x])       // user royalties earned between x and y
            //         - (TCR[i] - TCR[x]) * p1  // user royalties earned between x and i
            //         + (TCR[j] - TCR[y]) * p2  // user royalties earned between y and j
            //
            // Example timeline:
            //
            //   | we start with this range |
            //   x             i           y          j
            //   | to remove   | to keep   | to add   |
            //   --------------------------------------
            //
            UcrRecord memory yUcr = _UCR_[tierId][account][locals.yUcrId];
            {
                uint256 ldaBalance1 = _getLdaBalanceAfterUcr(tierId, account, locals.xUcrId);
                uint256 ldaBalance2 = _getLdaBalanceAfterUcr(tierId, account, locals.yUcrId);
                locals.p1 = _getProRataOwnership(ldaBalance1, ldaSupply);
                locals.p2 = _getProRataOwnership(ldaBalance2, ldaSupply);
            }
            uint256 xyUcrDiff = yUcr.value - xUcr.value;
            uint256 xiTcrDiff = _TCR_[tierId][locals.i].value - _TCR_[tierId][locals.x].value;
            uint256 xiUcrDiff = _tcrDiffToUcrDiff(xiTcrDiff, locals.p1);
            uint256 yjTcrDiff = _TCR_[tierId][locals.j].value - _TCR_[tierId][locals.y].value;
            uint256 yjUcrDiff = _tcrDiffToUcrDiff(yjTcrDiff, locals.p2);
            uceDiff = xyUcrDiff - xiUcrDiff + yjUcrDiff;
        }

        // Update storage.
        uint256 newUceValue = uceRecord.value + uceDiff;
        _UCE_[tierId][account] = UceRecord({
            depositId: locals.j.toUint64(), // lastExpiredDepositId
            ucrId: locals.yUcrId.toUint64(),
            value: newUceValue.toUint128()
        });
        _TCE_[tierId] = _TCE_[tierId] + uceDiff;

        emit DepositsReclaimable(
            tierId,
            account,
            locals.j
        );

        // Return the current UCE value.
        return newUceValue;
    }
