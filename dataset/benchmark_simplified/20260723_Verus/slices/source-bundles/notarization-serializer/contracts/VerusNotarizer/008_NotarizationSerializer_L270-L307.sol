    function deserializeProofRoots (bytes memory notarization, uint32 size, uint32 nextOffset) private view returns (bytes32 stateRoot, uint32 height)
    {
        for (uint i = 0; i < size; i++)
        {
            uint16 proofType;
            address systemID;
            bytes32 tempStateRoot;
            uint32 tempHeight;

            assembly {
                nextOffset := add(nextOffset, 2) // move to version
                nextOffset := add(nextOffset, 2) // move to read type
                proofType := mload(add(notarization, nextOffset))      // read proofType 
                nextOffset := add(nextOffset, CURRENCY_LENGTH) // move to read systemID
                systemID := mload(add(notarization, nextOffset))  
                nextOffset := add(nextOffset, 4) // move to height
                tempHeight := mload(add(notarization, nextOffset))  
                nextOffset := add(nextOffset, BYTES32_LENGTH) // move to read stateroot
                tempStateRoot := mload(add(notarization, nextOffset))  
                nextOffset := add(nextOffset, BYTES32_LENGTH) // move to read blockhash
                nextOffset := add(nextOffset, BYTES32_LENGTH) // move to power
            }
            
            if(systemID == VERUS)
            {
                stateRoot = tempStateRoot;
                height = serializeUint32(tempHeight); //swapendian
            }

            //swap 16bit endian
            if(((proofType >> 8) | (proofType << 8)) == PROOF_TYPE_ETH){
                assembly {
                    nextOffset := add(nextOffset, 8) // move to gasprice
                }
            }
        }
 
    }
