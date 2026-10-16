    function setNotarizationProofRoot(bytes32 hashedNotarization, 
            bytes32 hashprevnotarization, bytes32 txidHash, bytes32 hashprevtxid, bytes32 proposer, bytes32 stateRoot) private 
    {
        int forkIdx = -1;
        int forkPos;
        
        VerusObjectsNotarization.NotarizationForks[] memory notarizations;   
        for (int i = 0; i < int(bestForks.length) ; i++) 
        {
            notarizations =  decodeNotarization(uint(i));
            // Notarization length is always +1 more than the amount we have, as slot is ready to be filled.
            for (int j = int(notarizations.length) - 2; j >= 0; j--)
            {
                if (hashprevnotarization == notarizations[uint(j)].hashOfNotarization ||
                        hashprevtxid == notarizations[uint(j)].txid)
                {
                    forkIdx = i;
                    forkPos = j;
                    break;
                }
            }
            if (forkIdx > -1)
            {
                break;
            }
        }

        if (forkIdx == -1 && bestForks.length != 0)
        {
            revert("invalid notarization hash");
        }

        if (forkIdx == -1){
            forkIdx = 0;
        }
        
        if (forkPos != int(notarizations.length) - 2 && bestForks.length != 0)  
        {
            forkIdx = int(bestForks.length);
            encodeNotarization(uint(forkIdx), notarizations[uint(0)]);
        }

        // If the position that is matched is the second stored one, then that becomes the new confirmed.
        if(forkPos == 1)
        {
            if (bestForks.length > 1)
            {
                delete bestForks;
                bestForks.push("");
            }
            
            //pack vout in at the end of the proposer 22 bytes ctransferdest
            encodeStandardNotarization(notarizations[1], abi.encode(hashedNotarization, 
                txidHash, proposer));

            // The proofs are indexed by height, the height is stored in the proposers last 32 bits. Stored ine the proof is stateroot and the previous proof height.

            proofs[bytes32(uint256(uint32(uint256(proposer >> FORKS_DATA_OFFSET_FOR_HEIGHT))))] = abi.encodePacked(stateRoot, uint32(uint256(notarizations[1].proposerPacked) >> FORKS_DATA_OFFSET_FOR_HEIGHT));

            // Set bridge launched if confirmed notarization contains Bridge Launched bit packed on the end of proposer

            if (!bridgeConverterActive && ((uint256(notarizations[1].proposerPacked) >> VerusConstants.UINT176_BITS_SIZE) & 0xff) == 1) {
                    bridgeConverterActive = true;
            }
        }
        else
        {
            encodeNotarization(uint(forkIdx), VerusObjectsNotarization.NotarizationForks(hashedNotarization,
                txidHash, proposer));
            // Write proofs entry so that if this notarization later becomes confirmed via fork resolution,
            // getLastConfirmedVRSCStateRoot() can find its stateRoot. Without this, a fork resolution sets
            // bestForks[0] slot 2 to this notarization's height, but proofs[height] would be empty.
            // Guard: notarizations is only populated when bestForks was non-empty (i.e. a previous
            // notarization existed). On the very first call bestForks is empty and notarizations has
            // length 0, so accessing notarizations[forkPos] would panic with array out-of-bounds.
            if (notarizations.length > 0) {
                proofs[bytes32(uint256(uint32(uint256(proposer >> FORKS_DATA_OFFSET_FOR_HEIGHT))))] = abi.encodePacked(stateRoot, uint32(uint256(notarizations[uint(forkPos)].proposerPacked) >> FORKS_DATA_OFFSET_FOR_HEIGHT));
            }
        }
    }
