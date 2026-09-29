    function _validateCommitment(
        CoreState memory _state,
        Commitment memory _commitment
    )
        private
        pure
        returns (uint256 numProposals_, uint256 lastProposalId_, uint48 offset_)
    {
        unchecked {
            uint256 firstUnfinalizedId = _state.lastFinalizedProposalId + 1;

            numProposals_ = _commitment.transitions.length;
            require(numProposals_ > 0, EmptyBatch());
            require(_commitment.firstProposalId <= firstUnfinalizedId, FirstProposalIdTooLarge());

            lastProposalId_ = _commitment.firstProposalId + numProposals_ - 1;
            require(lastProposalId_ < _state.nextProposalId, LastProposalIdTooLarge());
            require(lastProposalId_ >= firstUnfinalizedId, LastProposalAlreadyFinalized());

            // Calculate offset to first unfinalized proposal.
            // Some proposals in _commitment.transitions[] may already be finalized.
            // The offset points to the first proposal that will be finalized.
            offset_ = uint48(firstUnfinalizedId - _commitment.firstProposalId);
        }
    }
