    function _validateHeaderProof(
        VerusObjects.CReserveTransferImport memory _import,
        uint32 elHashSize,
        uint32 nVins,
        uint32 nVouts,
        uint32 nShieldedSpends
    ) private pure {
        VerusObjects.CComponents memory comp0 = _import.partialtransactionproof.components[0];

        // component[0] must declare itself as a TX_HEADER; this is also enforced downstream
        // by proveComponents and checkExportAndTransfers, but fail fast here.
        require(comp0.elType == TX_HEADER, "comp0 must be TX_HEADER");

        require(
            comp0.elProof.length == 1 &&
            comp0.elProof[0].branchType == BRANCH_MMRBLAKE_NODE,
            "Invalid header proof type"
        );

        VerusObjects.CMerkleBranch memory b0 = comp0.elProof[0].proofSequence;

        require(elHashSize > 0,                "Empty tx element set");
        require(b0.nSize == elHashSize,        "Header nSize mismatch");
        // GetMMRProofIndex(0, nSize, 0) always returns 0; header must be at position 0
        require(b0.nIndex == 0,                "Header nIndex must be 0");
        require(b0.extraHashes == 0,           "Header extraHashes must be 0");
        require(b0.branch.length > 0,          "Empty header branch");

        // --- Anti-spoofing check (capped proofs only) ---
        // The last branch element encodes the total element count, preventing the prover
        // from extending the tree to a larger size than was actually committed.
        require(
            _import.partialtransactionproof.version >= VERSION_TXHASH_CAP,
            "Only capped proofs accepted"
        );
        require(
            _decodeCappedSize(b0.branch[b0.branch.length - 1]) == elHashSize,
            "Capped: size hash mismatch"
        );

        // --- Per-component structural validation ---
        // Each component i >= 1 must:
        //   1. Have exactly one BRANCH_MMRBLAKE_NODE proof over the same elHashSize tree.
        //   2. Have a non-empty branch (so checkBranch never operates on zero hashes).
        //   3. Claim an element index within the known bounds for its type.
        //   4. Declare an nIndex equal to the expected MMR leaf position for (elType, elIdx).
        //
        // Note on branch.length: in Verus's MMR the proof length is POSITION-DEPENDENT, not
        // only nSize-dependent (e.g. position 1 in a 6-element tree needs 3 hashes; position 5
        // needs only 2).  branch.length is implicitly validated by proveComponents — an
        // incorrect length produces an intermediate-node or post-root hash, which won't match
        // the committed txRoot.  This reasoning holds ONLY when extraHashes == 0 is enforced
        // below; a free extraHashes shifts GetMMRProofIndex's bit-positions and breaks the
        // canonical path binding that makes the nIndex check meaningful.
        //
        // The cryptographic binding is:
        //   nSize == elHashSize  → proof is from the same-size tree as the header
        //   nIndex == expected   → element is at the correct MMR leaf for its (type, idx)
        //   extraHashes == 0     → GetMMRProofIndex produces the canonical path for nIndex
        //   proveComponents      → the element hash at nIndex produces the committed txRoot
        for (uint i = 1; i < _import.partialtransactionproof.components.length; i++) {
            VerusObjects.CComponents memory comp = _import.partialtransactionproof.components[i];

            require(
                comp.elProof.length == 1 &&
                comp.elProof[0].branchType == BRANCH_MMRBLAKE_NODE &&
                comp.elProof[0].proofSequence.nSize == elHashSize,
                "Component proof invalid"
            );

            // Explicit branch non-empty check: mirrors the comp0 check above.
            // proveComponents/checkBranch would also catch this, but fail early and clearly.
            require(comp.elProof[0].proofSequence.branch.length > 0, "Empty component branch");

            // The only legitimate value for
            // transaction-component MMR proofs is 0.
            require(comp.elProof[0].proofSequence.extraHashes == 0, "extraHashes must be 0");

            // Capped proof anti-spoofing for subsequent components: the last branch element
            // must equal elHashSize (same as the check already done on component[0]).
            // Since version >= VERSION_TXHASH_CAP is required for the whole proof, every
            // component's branch must have been generated against the same committed tree size.
            // An attacker cannot forge this: the last element participates in the hash chain
            // verified by proveComponents, so a wrong value produces a wrong txRoot.
            require(
                _decodeCappedSize(comp.elProof[0].proofSequence.branch[comp.elProof[0].proofSequence.branch.length - 1]) == elHashSize,
                "Capped: component size hash mismatch"
            );

            uint8 elType = comp.elType;
            uint8 elIdx  = comp.elIdx;

            // Bounds check per element type (elIdx must be < the relevant count from the header).
            // These counts come from the cryptographically-proven header bytes, so after
            // proveComponents verifies the header hash these bounds are themselves proven.
            if (elType == TX_PREVOUTSEQ || elType == TX_SIGNATURE_TYPE) {
                require(elIdx < nVins,          "vin idx out of bounds");
            } else if (elType == TYPE_TX_OUTPUT) {
                require(elIdx < nVouts,         "vout idx out of bounds");
            } else if (elType == TX_SHIELDEDSPEND) {
                require(elIdx < nShieldedSpends, "shielded spend idx OOB");
            }

            // nIndex must match the expected MMR leaf position for this (elType, elIdx).
            // Combined with proveComponents this is the cryptographic position guarantee:
            // if nIndex is wrong the Merkle path diverges and txRoot won't match.
            uint32 expected = _mmrPosition(elType, elIdx, nVins, nVouts, nShieldedSpends);
            require(
                comp.elProof[0].proofSequence.nIndex == expected,
                "Component nIndex mismatch"
            );
        }
    }
