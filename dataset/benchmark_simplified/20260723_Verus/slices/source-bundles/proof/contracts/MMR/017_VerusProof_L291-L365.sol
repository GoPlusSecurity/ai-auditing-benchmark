    function _readCCEFields(bytes memory firstObj, uint32 nextOffset)
        private pure
        returns (CCEData memory cce)
    {
        // Validate CCE nVersion == 1 (LE bytes 0x01 0x00; read big-endian = 0x0100).
        // CCE.nVersion is 4 bytes before nextOffset: data[nextOffset-4..nextOffset-3].
        // uint16 mload at (nextOffset-2) reads the last 2 bytes = data[nextOffset-4..nextOffset-3].
        uint16 cceNVersion;
        assembly { cceNVersion := mload(add(firstObj, sub(nextOffset, 2))) }
        require(serializeUint16(cceNVersion) >= CCE_NVERSION_1, "CCE nVersion must be 1");

        // Only FLAG_POSTLAUNCH (0x0080) must be set; accept FLAG_UNUSED  0x20
   
        assembly {
            let mask := 0xDFFF // only FLAG_POSTLAUNCH (0x0080) must be set; accept FLAG_UNUSED  0x20, note flipped endian.
            if iszero(eq(and(mload(add(firstObj, nextOffset)), mask), 0x8000)) { revert(0, 0) }
        }

        // sourceSystemID (uint160, 20 bytes): advance past it and read as address
        nextOffset += CCE_SOURCE_SYSTEM_DELTA;
        address srcSys;
        assembly { srcSys := mload(add(firstObj, nextOffset)) }
        cce.sourceSystemID = srcSys;

        // hashReserveTransfers (uint256, 32 bytes)
        nextOffset += CCE_HASH_TRANSFERS_DELTA;
        bytes32 hRT;
        assembly { hRT := mload(add(firstObj, nextOffset)) }
        cce.hashReserveTransfers = hRT;

        // destSystemID (uint160, 20 bytes)
        nextOffset += CCE_DEST_SYSTEM_DELTA;
        address dstSys;
        assembly { dstSys := mload(add(firstObj, nextOffset)) }
        cce.destSystemID = dstSys;

        // destCurrencyID (uint160, 20 bytes)
        nextOffset += CCE_DEST_CURRENCY_DELTA;
        address dstCur;
        assembly { dstCur := mload(add(firstObj, nextOffset)) }
        cce.destCurrencyID = dstCur;

        // exporter (CTransferDestination): type(1 byte) | length(1 byte) | dest-bytes
        // Delegate to helper to avoid stack-too-deep (collects up to 3 exporter addresses,
        // returns the last non-zero one and the advanced offset).
        {
            nextOffset += 1;
            uint8 exporterType;
            assembly { exporterType := mload(add(firstObj, nextOffset)) }
            nextOffset += 1;
            VerusObjectsCommon.UintReader memory exporterLenReader = readCompactSizeLE(firstObj, nextOffset);
            require(exporterLenReader.value <= type(uint16).max, "Exporter length too large");
            (nextOffset, cce.exporter, cce.exporter2, cce.exporter3) = _collectExporter(firstObj, uint32(exporterLenReader.offset), exporterType, uint16(exporterLenReader.value));
        }

        // firstInput (int32 LE, 4 bytes) is skipped; numInputs (int32 LE, 4 bytes) is read.
        // After += 8, the rightmost 4 bytes of mload = numInputs bytes in memory order.
        // serializeUint32 byte-reverses to obtain the correct integer value.
        uint32 numInputsRaw;
        assembly {
            nextOffset  := add(nextOffset, 8)
            numInputsRaw := mload(add(firstObj, nextOffset))
        }
        cce.numInputs = serializeUint32(numInputsRaw);

        // VARINT(sourceHeightStart) then VARINT(sourceHeightEnd)
        uint32 startH;
        uint32 endH;
        (startH, nextOffset) = readVarint(firstObj, nextOffset);
        cce.sourceHeightStart = startH;
        (endH, nextOffset)    = readVarint(firstObj, nextOffset);
        cce.sourceHeightEnd   = endH;

        require(firstObj[firstObj.length - 1] == 0x75, "Script must end with OP_DROP (0x75)");
    }
