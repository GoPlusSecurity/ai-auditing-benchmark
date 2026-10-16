    function proveImports(bytes calldata dataIn ) external view returns(uint128, uint176, uint176, uint176){
        
        // txCounts packs: bits 0-31 elHashSize, 32-63 nVins, 64-95 nVouts, 96-127 nShieldedSpends
        // Use a scoped block so txCounts and the count unpacking go out of scope before
        // exporter2/exporter3 are declared, preventing stack-too-deep.
        VerusObjects.CReserveTransferImport memory _import;
        bytes32 hashOfTransfers;
        {
            uint128 txCounts;
            (_import, hashOfTransfers, txCounts) = abi.decode(dataIn, (VerusObjects.CReserveTransferImport, bytes32, uint128));

            _validateHeaderProof(
                _import,
                uint32(txCounts),
                uint32(txCounts >> 32),
                uint32(txCounts >> 64),
                uint32(txCounts >> 96)
            );
        }

        uint128 heightsAndTXNum;
        uint176 exporter;
        uint176 exporter2;
        uint176 exporter3;

        (heightsAndTXNum, exporter, exporter2, exporter3) = checkExportAndTransfers(_import, hashOfTransfers);

        {
            bytes32 txRoot = proveComponents(_import);
            if(txRoot == bytes32(0)) revert("Components do not validate");

            require(_import.partialtransactionproof.txproof.length == NUM_TX_PROOFS);

            bytes32 retStateRoot = checkProof(txRoot, _import.partialtransactionproof.txproof);
            if (retStateRoot == bytes32(0) || retStateRoot != getLastConfirmedVRSCStateRoot()) {
                revert("Stateroot does not match");
            }
        }

        return (heightsAndTXNum, exporter, exporter2, exporter3);
    }
