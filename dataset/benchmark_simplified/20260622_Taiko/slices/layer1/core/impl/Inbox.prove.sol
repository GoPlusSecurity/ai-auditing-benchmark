    function prove(bytes calldata _data, bytes calldata _proof) external nonReentrant {
        unchecked {

            CoreState memory state = _coreState;
            ProveInput memory input = LibCodec.decodeProveInput(_data);

            // -------------------------------------------------------------------------------
            // 1. Validate batch bounds and calculate offset of the first unfinalized proposal
            // -------------------------------------------------------------------------------
            Commitment memory commitment = input.commitment;

            // `offset` is the index of the next-to-finalize proposal in the transitions array.
            (uint256 numProposals, uint256 lastProposalId, uint48 offset) =
                _validateCommitment(state, commitment);

            uint256 proposalAge = block.timestamp - commitment.transitions[offset].timestamp;
            bool isWhitelistEnabled = _checkProver(msg.sender, proposalAge);

            // ---------------------------------------------------------
            // 2. Verify parent block-hash continuity and last proposal hash
            // ---------------------------------------------------------
            // The parent block hash must match the stored lastFinalizedBlockHash.
            bytes32 expectedParentHash = offset == 0
                ? commitment.firstProposalParentBlockHash
                : commitment.transitions[offset - 1].blockHash;
            require(state.lastFinalizedBlockHash == expectedParentHash, ParentBlockHashMismatch());

            require(
                commitment.lastProposalHash == getProposalHash(lastProposalId),
                LastProposalHashMismatch()
            );

            // ---------------------------------------------------------
            // 3. Process bond instruction
            // ---------------------------------------------------------
            // Bond transfers only apply when whitelist is not enabled.
            if (!isWhitelistEnabled) {
                _processLivenessBond(commitment, offset);
            }

            // -----------------------------------------------------------------------------
            // 4. Sync checkpoint
            // -----------------------------------------------------------------------------
            _signalService.saveCheckpoint(
                ICheckpointStore.Checkpoint({
                    blockNumber: commitment.endBlockNumber,
                    stateRoot: commitment.endStateRoot,
                    blockHash: commitment.transitions[numProposals - 1].blockHash
                })
            );
            state.lastCheckpointTimestamp = uint48(block.timestamp);

            // ---------------------------------------------------------
            // 5. Update core state and emit event
            // ---------------------------------------------------------
            state.lastFinalizedProposalId = uint48(lastProposalId);
            state.lastFinalizedTimestamp = uint48(block.timestamp);
            state.lastFinalizedBlockHash = commitment.transitions[numProposals - 1].blockHash;

            _coreState = state;

            emit Proved(
                commitment.firstProposalId,
                commitment.firstProposalId + offset,
                uint48(lastProposalId),
                commitment.actualProver
            );

            // ---------------------------------------------------------
            // 6. Verify the proof
            // ---------------------------------------------------------
            // For multi-proposal batches (more than 1 unfinalized proposal), pass 0 to verifier.
            // Single-proposal proofs pass actual age for age-based verification logic.
            _proofVerifier.verifyProof(
                numProposals - offset == 1 ? proposalAge : 0,
                LibHashOptimized.hashCommitment(commitment),
                _proof
            );
        }
    }
