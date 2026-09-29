    function getProposalHash(uint256 _proposalId) public view returns (bytes32) {
        return _proposalHashes[_proposalId % _ringBufferSize];
    }
