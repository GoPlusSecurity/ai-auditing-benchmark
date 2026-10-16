    function _createImports(bytes calldata data) external returns(uint64, uint176) {

        if (storageGlobal[SUBMIT_IMPORTS_REENTRANCY_GUARD].length != 0) revert();
        storageGlobal[SUBMIT_IMPORTS_REENTRANCY_GUARD] = abi.encodePacked(uint8(1));

        if (claimableFees[VerusConstants.VDXF_DISABLE_CONTRACT_KEY] & VerusConstants.HALT_SUBMIT_IMPORTS != 0) revert();

        uint256 gasleftStart = gasleft();
        VerusObjects.CReserveTransferImport memory _import = abi.decode(data, (VerusObjects.CReserveTransferImport));

        // Parse CTransactionHeader from component 0 and validate the txid is not a replay.
        TxHeaderData memory hdr = _parseTxHeader(_import.partialtransactionproof.components[0].elVchObj);

        if (processedTxids[hdr.txHash]) 
        {
            revert();
        } 

        bool success;
        bytes memory returnBytes;
        bytes32 hashOfTransfers = keccak256(_import.serializedTransfers);
        uint128 CCEHeightsAndnIndex;
        // exporters[0]=main dest, exporters[1]=first aux, exporters[2]=second aux
        uint176[3] memory exporters;

        // Scope A: build txCounts and delegatecall proveImports (txCounts released after block)
        {
            uint128 txCounts = uint128(1 + 2 * hdr.nVins + hdr.nVouts + hdr.nShieldedSpends + hdr.nShieldedOutputs)
                | (uint128(hdr.nVins) << 32)
                | (uint128(hdr.nVouts) << 64)
                | (uint128(hdr.nShieldedSpends) << 96);
            (success, returnBytes) = contracts[uint(VerusConstants.ContractType.VerusProof)].delegatecall(
                abi.encodeWithSignature("proveImports(bytes)", abi.encode(_import, hashOfTransfers, txCounts))
            );
            require(success);
        }

        // Scope B: decode 3 exporters into array (temps e0/e1/e2 released after block)
        {
            uint176 e0; uint176 e1; uint176 e2;
            (CCEHeightsAndnIndex, e0, e1, e2) = abi.decode(returnBytes, (uint128, uint176, uint176, uint176));
            uint176 flagMask = 0x0fffffffffffffffffffffffffffffffffffffffffff;
            exporters[0] = e0 & flagMask;
            exporters[1] = e1 & flagMask;
            exporters[2] = e2 & flagMask;
        }

        isLastCCEInOrder(uint32(CCEHeightsAndnIndex));
   
        // clear 4 bytes above first 64 bits, i.e. clear the nIndex 32 bit number, then convert to correct nIndex
        // Using the index for the proof (ouput of an export) - (header ( 2 * nvin )) == export output
        // NOTE: This depends on the serialization of the CTransaction header and the location of the vins being 45 bytes in.
        // NOTE: Also depends on it being a partial transaction proof, header = 1

        CCEHeightsAndnIndex  = (CCEHeightsAndnIndex & 0xffffffff00000000ffffffffffffffff) | (uint128(uint32(uint32(CCEHeightsAndnIndex >> 64) - (1 + (2 * hdr.nVins)))) << 64);  
        setLastImport(hdr.txHash, hashOfTransfers, CCEHeightsAndnIndex);
        
        // get the gasleft before calling the tokenmanager

        //returns success, refund addresses bytes & refund address array which is abi.encoded-ed, these are any refunds that didnt pay out.
        (success, returnBytes) = contracts[uint(VerusConstants.ContractType.TokenManager)].delegatecall(abi.encodeWithSelector(TokenManager.processTransactions.selector, _import.serializedTransfers, uint256(uint32(CCEHeightsAndnIndex >> 96))));
        require(success);

        uint176[] memory refundAddresses;
        uint64 fees;

        // returns refundaddresses bytes, fees and refundaddresses
        (returnBytes, fees, refundAddresses) = abi.decode(returnBytes, (bytes, uint64, uint176[]));

        // get the cceblockwidth of the cce from endheight - startheight and copy back into CCEHeightsAndnIndex
        CCEHeightsAndnIndex = (uint32(CCEHeightsAndnIndex >> 32) - uint32(CCEHeightsAndnIndex));

        // calculate the fee to pay any refunds, and then pay to the refund addresses.
        calulateGasFees(gasleftStart, fees, refundAddresses, CCEHeightsAndnIndex, exporters);

        if (returnBytes.length > 0) {
            refund(returnBytes);
        }

        delete storageGlobal[SUBMIT_IMPORTS_REENTRANCY_GUARD];

        return (0,0);
    }
