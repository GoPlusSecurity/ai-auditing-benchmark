    function setLatestData(bytes calldata serializedNotarization, bytes32 txid, uint32 n, bytes calldata data
        ) external {

        if (claimableFees[VerusConstants.VDXF_DISABLE_CONTRACT_KEY] & VerusConstants.HALT_NOTARIZATIONS != 0) revert("Bridge halted");

        require(!knownNotarizationTxids[txid], "known TXID");
        knownNotarizationTxids[txid] = true;

        (uint8[] memory _vs,
        bytes32[] memory _rs,
        bytes32[] memory _ss,
        uint32[] memory blockheights,
        address[] memory notaryAddresses) = abi.decode(data,(uint8[],bytes32[], bytes32[],uint32[],address[]));

        bytes32 keccakNotarizationHash;
        bytes32 txidHash;
        
        txidHash = keccak256(abi.encodePacked(txid, serializeUint32(n)));

        keccakNotarizationHash = keccak256(serializedNotarization);

        uint i;
        bytes memory tempBytes;

        tempBytes =  abi.encodePacked(
                    vdxfcodePlusVersion,
                    txidHash,
                    VERUS,
                    serializeUint32(blockheights[i]),
                    notaryAddresses[i], 
                    keccakNotarizationHash);

        for(; i < notaryAddresses.length; i++)
        {
            if (i < (notaryAddresses.length - 1)) {
                checkunique(notaryAddresses, i);
            }
            
            bytes32 hashedNotarizationByID;
            // hash the notarizations with the vdxf key, system, height & NotaryID. the address is masked in 98 bytes in .
            assembly {
                mstore(add(tempBytes, 98), or(and(mload(add(tempBytes, 98)), shl(160, 0xffffffffffffffffffffffff)), mload(add(notaryAddresses, mul(add(i,1), 32)))))
                hashedNotarizationByID := keccak256(add(tempBytes, 0x20), mload(tempBytes))
            }

           // hashedNotarizationByID = keccak256(tempBytes);

            if (ecrecover(hashedNotarizationByID, _vs[i]-4, _rs[i], _ss[i]) != notaryAddressMapping[notaryAddresses[i]].main)
            {
                revert("Invalid notary signature");  
            }
            if (notaryAddressMapping[notaryAddresses[i]].state != VerusConstants.NOTARY_VALID)
            {
                revert("Notary revoked"); 
            }
        }

        if(i < ((notaries.length >> 1) + 1 ))
        {
            revert("not enough notary signatures");
        }

        checkNotarization(serializedNotarization, txid, uint64(n));
    }
