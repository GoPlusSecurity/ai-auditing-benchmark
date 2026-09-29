    function _getCheckpoint(uint48 _blockNumber)
        private
        view
        returns (Checkpoint memory checkpoint_)
    {
        CheckpointRecord storage record = _checkpoints[_blockNumber];
        bytes32 blockHash = record.blockHash;
        if (blockHash == bytes32(0)) revert SS_CHECKPOINT_NOT_FOUND();

        checkpoint_ = Checkpoint({
            blockNumber: _blockNumber, blockHash: blockHash, stateRoot: record.stateRoot
        });
    }
