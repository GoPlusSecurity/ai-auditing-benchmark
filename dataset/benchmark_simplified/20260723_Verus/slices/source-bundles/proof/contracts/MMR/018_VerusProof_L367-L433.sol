    function checkExportAndTransfers(VerusObjects.CReserveTransferImport memory _import, bytes32 hashedTransfers) public view returns (uint128, uint176, uint176, uint176) {

        bool foundInput = false;
        bool inputMatchesLastCCE = false;
        bytes32 lastTxid = lastImportInfo[VerusConstants.SUBMIT_IMPORTS_LAST_TXID].exporttxid;

        for (uint i = 1; i < _import.partialtransactionproof.components.length; i++) {
            uint8 elType = _import.partialtransactionproof.components[i].elType;

            // TX_PREVOUTSEQ (type 2): deserialize the COutPoint from elVchObj.
            // COutPoint wire format (from BaseOutPoint::SerializationOp):
            //   hash (uint256, 32 bytes LE) | n (uint32, 4 bytes LE)
            // Validate that at least one input spends from the previous CCE transaction.
            if (elType == TX_PREVOUTSEQ) {
                bytes memory prevoutData = _import.partialtransactionproof.components[i].elVchObj;
                require(prevoutData.length >= 36, "Prevout elVchObj too short");
                bytes32 prevoutHash;
                // mload(add(ptr, 32)) reads data[0..31] as bytes32 — the COutPoint.hash
                assembly { prevoutHash := mload(add(prevoutData, 32)) }
                foundInput = true;
                // On the first import lastTxid is zero; skip the hash check in that case.
                if (lastTxid == bytes32(0) || prevoutHash == lastTxid) {
                    inputMatchesLastCCE = true;
                }
                continue;
            }

            if (elType != TYPE_TX_OUTPUT)
                continue;

            // Every import must prove at least one input that spends from the last CCE tx.
            require(foundInput, "No TX input component found");
            require(inputMatchesLastCCE, "Input does not spend from last CCE tx");

            bytes memory firstObj = _import.partialtransactionproof.components[i].elVchObj;
            uint32 nIndex = _import.partialtransactionproof.components[i].elProof[0].proofSequence.nIndex;

            // Parse CTxOut: validate scriptPubKey structure and locate the CCE body
            (uint32 cceBodyOffset, bool ok) = _parseCTxOut(firstObj);
            if (!ok) revert("No CCE output component proven"); 

            // Deserialize CCE fields from the located body
            CCEData memory cce = _readCCEFields(firstObj, cceBodyOffset);

            // Validate: correct source chain, correct destination chain, correct currency, correct transfer hash
            if (!(cce.hashReserveTransfers == hashedTransfers &&
                  cce.sourceSystemID == VERUS &&
                  cce.destSystemID   == VETH &&
                  cce.destCurrencyID == VETH)) {
                revert("CCE information does not checkout");
            }

            // Pack heights + nIndex + numInputs into a single uint128 for the caller.
            // Layout (matches SubmitImports unpack convention):
            //   bits  0-31 : sourceHeightStart
            //   bits 32-63 : sourceHeightEnd
            //   bits 64-95 : nIndex (output position in the tx)
            //   bits 96-127: numInputs (= number of reserve transfers)
            uint128 packed = uint128(cce.sourceHeightStart)
                           | (uint128(cce.sourceHeightEnd) << 32)
                           | (uint128(nIndex)              << 64)
                           | (uint128(cce.numInputs)       << 96);

            return (packed, cce.exporter, cce.exporter2, cce.exporter3);
        }
        return (uint128(0), uint176(0), uint176(0), uint176(0));
    }
