    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    )
        internal
        virtual
        override
    {
        // Iterate over all LDAs being transferred
        for (uint256 i; i < ids.length; i++) {
            uint256 ldaId = ids[i];

            // Get the tier ID.
            (uint128 tierId, ,) = RoyalUtil.decomposeLDA_ID(ldaId);

            // Call the callback on the Royalties contract.
            //
            // IMPORTANT: This must happen before any bookkeeping like `_OWNED_TOKENS_` is updated.
            if (_ROYALTIES_CONTRACT_ != address(0)) {
                ILdaTransferHook(_ROYALTIES_CONTRACT_).beforeLdaTransfer(from, to, tierId);
            }

            // Self-transfer: skip everything that follows.
            if (from == to) {
                continue;
            }

            // Token leaves a wallet: update balance and remove token from owner enumeration.
            if (from != address(0)) {
                uint256 balance = _BALANCES_[tierId][from];

                // Special case: If backfill is ongoing AND balance is zero, do not update.
                if (_IS_OWNED_TOKENS_BACKFILL_COMPLETE_ || balance != 0) {
                    require(
                        balance != 0,
                        "ERC1155: insufficient balance for transfer"
                    );

                    // Remove from owned tokens list using swap-and-pop method.
                    uint256 lastTokenIndex = balance - 1;
                    uint256 removeTokenIndex = _OWNED_TOKENS_INDEX_[ldaId];

                    if (lastTokenIndex != removeTokenIndex) {
                        uint256 lastTokenId = _OWNED_TOKENS_[tierId][from][lastTokenIndex];
                        _OWNED_TOKENS_[tierId][from][removeTokenIndex] = lastTokenId;
                        _OWNED_TOKENS_INDEX_[lastTokenId] = removeTokenIndex;
                    }

                    delete _OWNED_TOKENS_[tierId][from][lastTokenIndex];
                    delete _OWNED_TOKENS_INDEX_[ldaId]; // NOTE: This deletion is optional.

                    _BALANCES_[tierId][from] = lastTokenIndex;
                }
            }

            // Token enters a wallet: update balance and add token to owner enumeration.
            if (to != address(0)) {
                uint256 oldBalance = _BALANCES_[tierId][to];
                _OWNED_TOKENS_[tierId][to][oldBalance] = ldaId;
                _OWNED_TOKENS_INDEX_[ldaId] = oldBalance;

                _BALANCES_[tierId][to] = oldBalance + 1;
            }

            if (from == address(0)) {
                // This is a mint operation
                // Add this LDA to the `to` address state
                _addTokenToTierTracking(to, ldaId, tierId);

            } else {
                // If this is a transfer to a different address.
                _OWNERS_[ldaId] = to;
            }

            if (to == address(0)) {
                // NOTE: no burn() is currently implemented
                // Remove LDA from being associated with its
                _removeLDAFromTierTracking(from, ldaId, tierId);
            }
        }

        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }
