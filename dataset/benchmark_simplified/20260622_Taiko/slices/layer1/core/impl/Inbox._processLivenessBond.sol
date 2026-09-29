    function _processLivenessBond(Commitment memory _commitment, uint48 _offset) private {
        unchecked {
            uint256 livenessWindowDeadline = (_commitment.transitions[_offset].timestamp
                    + _provingWindow)
            .max(_coreState.lastFinalizedTimestamp + _maxProofSubmissionDelay);

            // On-time proof - no bond transfer needed.
            if (block.timestamp <= livenessWindowDeadline) {
                return;
            }

            _bondStorage.settleLivenessBond(
                _commitment.transitions[_offset].proposer, _commitment.actualProver, _livenessBond
            );
        }
    }
