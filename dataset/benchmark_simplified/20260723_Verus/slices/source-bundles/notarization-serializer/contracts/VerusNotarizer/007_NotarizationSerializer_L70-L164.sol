    function deserializeNotarization(bytes memory notarization) external returns (bytes32 proposerAndLaunched, 
                                                                                    bytes32 prevnotarizationtxid, 
                                                                                    bytes32 hashprevcrossnotarization, 
                                                                                    bytes32 stateRoot, 
                                                                                    uint32 height) {
        
        uint32 nextOffset;
        uint16 bridgeConverterLaunched;
        uint8 proposerType;
        uint32 notarizationFlags;
        uint176 proposerMain;

        VerusObjectsCommon.UintReader memory readerLen;

        readerLen = readVarintStruct(notarization, 0);    // get the length of the varint version
        readerLen = readVarintStruct(notarization, readerLen.offset);        // get the length of the flags

        notarizationFlags = uint32(readerLen.value);
        nextOffset = readerLen.offset;

        require(
            (notarizationFlags & REQUIRED_NOTARIZATION_FLAGS) == REQUIRED_NOTARIZATION_FLAGS &&
            (notarizationFlags & ~ALLOWED_NOTARIZATION_FLAGS) == 0,
            "invalid notarization flags"
        );

        assembly {
                    nextOffset := add(nextOffset, 1)  // move to read type
                    proposerType := mload(add(nextOffset, notarization))
                    if gt(and(proposerType, 0xff), 0) {
                        nextOffset := add(nextOffset, 21) // move to proposer, type and vector length
                        proposerMain := mload(add(nextOffset, notarization))
                        //remove type flags of proposer.
                        proposerMain := and(proposerMain, 0x0fffffffffffffffffffffffffffffffffffffffffff)
                    }
                 }

        if (proposerType & VerusConstants.FLAG_DEST_GATEWAY == VerusConstants.FLAG_DEST_GATEWAY)
        {
            nextOffset += VerusConstants.FLAG_DEST_GATEWAY_LENGTH;  // skip past gateway ID to get to auxdest vector length
        }

        if (proposerType & VerusConstants.FLAG_DEST_AUX == VerusConstants.FLAG_DEST_AUX)
        {
            nextOffset += 1;  // goto auxdest parent vec length position
            nextOffset = processAux(notarization, nextOffset);
            nextOffset -= 1;  // NOTE: Next Varint call takes array pos not array pos +1
        }
        //position 0 of the rolling vote is use to determine whether votes have started
        else if (rollingVoteIndex != VerusConstants.DEFAULT_INDEX_VALUE){
            castVote(address(0));
        }

        address currencyid;
        assembly {
                    nextOffset := add(nextOffset, CURRENCY_LENGTH) //skip currencyid
                    currencyid := mload(add(notarization, nextOffset))      // currencyid
                 }
        require(currencyid == VETH, "invalid notarization currencyid");

        (, nextOffset) = deserializeCoinbaseCurrencyState(notarization, nextOffset);

        assembly {
                    nextOffset := add(nextOffset, 4) // skip notarizationheight
                    nextOffset := add(nextOffset, BYTES32_LENGTH) // move to read prevnotarizationtxid
                    prevnotarizationtxid := mload(add(notarization, nextOffset))      // prevnotarizationtxid 
                    nextOffset := add(nextOffset, 4) //skip prevnotarizationout
                    nextOffset := add(nextOffset, BYTES32_LENGTH) // move to read hashprevcrossnotarization
                    hashprevcrossnotarization := mload(add(notarization, nextOffset))      // hashprevcrossnotarization 
                    nextOffset := add(nextOffset, 4) //skip prevheight
                    nextOffset := add(nextOffset, 1) //move to read length of notarizationcurrencystate
                }

        readerLen = readCompactSizeLE(notarization, nextOffset);    // get the length of the currencyState

        nextOffset = readerLen.offset - 1;   //readCompactSizeLE returns offset of next byte so move back to start of currencyState

        for (uint i = 0; i < readerLen.value; i++)
        {
            uint16 temp; // store the currency state flags
            (temp, nextOffset) = deserializeCoinbaseCurrencyState(notarization, nextOffset);
            bridgeConverterLaunched |= temp;
        }
        
        proposerAndLaunched = bytes32(uint256(proposerMain));
       
        if (!bridgeConverterActive && bridgeConverterLaunched > 0) {
                proposerAndLaunched |= bytes32(uint256(bridgeConverterLaunched) << VerusConstants.UINT176_BITS_SIZE);  // Shift 16bit value 22 bytes to pack in bytes32
        }

        nextOffset++; //move forwards to read le
        readerLen = readCompactSizeLE(notarization, nextOffset);    // get the length of proofroot array

        (stateRoot, height) = deserializeProofRoots(notarization, uint32(readerLen.value), nextOffset);
    }
