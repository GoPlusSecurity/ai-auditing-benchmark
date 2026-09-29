    function verifyProof(
        uint256 _proposalAge,
        bytes32 _commitmentHash,
        bytes calldata _proof
    )
        external
        view
        virtual
    {
        SubProof[] memory subProofs = abi.decode(_proof, (SubProof[]));
        uint256 size = subProofs.length;
        address[] memory verifiers = new address[](size);

        VerifierType lastVerifierId;

        for (uint256 i; i < size; ++i) {
            VerifierType verifierId = subProofs[i].verifierId;

            require(verifierId != VerifierType.NONE, CV_INVALID_SUB_VERIFIER());
            require(verifierId > lastVerifierId, CV_INVALID_SUB_VERIFIER_ORDER());

            address verifier = getVerifierAddress(verifierId);
            require(verifier != address(0), CV_INVALID_SUB_VERIFIER());

            IProofVerifier(verifier).verifyProof(_proposalAge, _commitmentHash, subProofs[i].proof);

            verifiers[i] = verifier;
            lastVerifierId = verifierId;
        }

        require(areVerifiersSufficient(verifiers), CV_VERIFIERS_INSUFFICIENT());
    }
