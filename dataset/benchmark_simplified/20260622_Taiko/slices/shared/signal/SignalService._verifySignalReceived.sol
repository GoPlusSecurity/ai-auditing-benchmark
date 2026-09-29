    function _verifySignalReceived(
        uint64 _chainId,
        address _app,
        bytes32 _signal,
        bytes calldata _proof
    )
        private
        view
    {
        require(_app != address(0), ZERO_ADDRESS());
        require(_signal != bytes32(0), ZERO_VALUE());

        bytes32 slot = getSignalSlot(_chainId, _app, _signal);
        if (_proof.length == 0) {
            require(_receivedSignals[slot], SS_SIGNAL_NOT_RECEIVED());
            return;
        }

        HopProof[] memory proofs = abi.decode(_proof, (HopProof[]));
        if (proofs.length != 1) revert SS_INVALID_PROOF_LENGTH();

        HopProof memory proof = proofs[0];

        if (proof.accountProof.length == 0 || proof.storageProof.length == 0) {
            revert SS_EMPTY_PROOF();
        }

        if (proof.blockId > type(uint48).max) {
            revert SS_INVALID_BLOCK_ID();
        }

        Checkpoint memory checkpoint = _getCheckpoint(uint48(proof.blockId));
        if (checkpoint.stateRoot != proof.rootHash) {
            revert SS_INVALID_CHECKPOINT();
        }

        LibTrieProof.verifyMerkleProof(
            checkpoint.stateRoot,
            _remoteSignalService,
            slot,
            _signal,
            proof.accountProof,
            proof.storageProof
        );
    }
