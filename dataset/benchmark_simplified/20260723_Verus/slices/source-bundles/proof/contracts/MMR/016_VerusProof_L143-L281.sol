    function _parseCTxOut(bytes memory firstObj)
        private pure
        returns (uint32 nextOffset, bool ok)
    {
        if (firstObj.length < OUTPUT_SCRIPT_OFFSET) return (0, false);

        // Step 1: skip nValue(8) and read scriptPubKey compact-size inline (LE encoding).
        //   single-byte form used for values 0-252,
        //   0xfd two-byte form used for 253-65535.
        //   0xfe/0xff forms imply script > 65535 bytes — rejected for our use case.
        {
            uint8 leadByte;
            uint32 scriptLen;
            assembly { leadByte := mload(add(firstObj, OUTPUT_SCRIPT_OFFSET)) }
            if (leadByte < 253) {
                scriptLen  = uint32(leadByte);
                nextOffset = OUTPUT_SCRIPT_OFFSET + 1;
            } else if (leadByte == 253) {
                if (firstObj.length < OUTPUT_SCRIPT_OFFSET + 2) return (0, false);
                uint8 lo; uint8 hi;
                assembly {
                    lo := mload(add(firstObj, add(OUTPUT_SCRIPT_OFFSET, 1)))
                    hi := mload(add(firstObj, add(OUTPUT_SCRIPT_OFFSET, 2)))
                }
                scriptLen = uint32(lo) | (uint32(hi) << 8);
                require(scriptLen >= 253, "Non-canonical compact-size");
                nextOffset = OUTPUT_SCRIPT_OFFSET + 3;
            } else {
                return (0, false); // 4- or 8-byte compact-size: script too large
            }
            // Mirrors IsPayToCryptoCondition: 0 < scriptLen ≤ MAX_SCRIPT_SIZE.
            if (scriptLen == 0 || scriptLen > MAX_SCRIPT_SIZE) return (0, false);
            // Full script must fit within firstObj.
            if (firstObj.length < nextOffset + scriptLen - 1) return (0, false);
        }
        uint8 op;

        // Step 2: master COptCCParams — must be a direct push (opcode 0x01-0x4b).
        assembly { op := mload(add(firstObj, nextOffset)) }
        nextOffset++;
        if (op < 0x01 || op > 0x4b) return (0, false);
        nextOffset += uint32(op); // skip firstParam data vector

        // Step 3: OP_CHECKCRYPTOCONDITION (0xcc).
        assembly { op := mload(add(firstObj, nextOffset)) }
        nextOffset++;
        if (op != SCRIPT_OP_CHECKCRYPTOCONDITION) return (0, false);

        // Step 4: PUSHDATA1/2 wrapping the secondary COptCCParams body.
        // Canonical check: PUSHDATA1 only if dataLen > 75; PUSHDATA2 only if dataLen > 255.
        uint32 COptCCParamsMainLength;
        {
            uint8 lenLo;
            assembly { op := mload(add(firstObj, nextOffset)) }
            nextOffset++;
            if (op == SCRIPT_OP_PUSHDATA1) {
                assembly { lenLo := mload(add(firstObj, nextOffset)) }
                if (lenLo <= 75) return (0, false); // non-canonical
                COptCCParamsMainLength = uint32(lenLo);
                nextOffset += 1;
            } else if (op == SCRIPT_OP_PUSHDATA2) {
                uint8 lenHi;
                assembly {
                    lenLo := mload(add(firstObj, nextOffset))
                    lenHi := mload(add(firstObj, add(nextOffset, 1)))
                }
                if (uint32(lenLo) | (uint32(lenHi) << 8) <= 255) return (0, false); // non-canonical
                COptCCParamsMainLength = uint32(lenLo) | (uint32(lenHi) << 8);
                nextOffset += 2;
            } else {
                return (0, false);
            }
            require(firstObj.length >= nextOffset + COptCCParamsMainLength, "Script too short for PUSHDATA2");
        }
        // nextOffset now points to the first byte of the secondary COptCCParams body.

        // Step 5: {version, evalCode, m, n} — a direct push of ≥4 bytes.
        {
            uint8 version; 
            uint8 evalCode;
            uint8 nKeys;
            assembly { op := mload(add(firstObj, nextOffset)) }
            nextOffset++;
            if (op != 0x04 ) return (0, false);
            
            // nextOffset-1 = version, nextOffset = evalCode, nextOffset+1 = m, nextOffset+2 = n
            assembly {
                version  := mload(add(firstObj, nextOffset))
                evalCode := mload(add(firstObj, add(nextOffset, 1)))
                // skip m keys
                nKeys    := mload(add(firstObj, add(nextOffset, 3)))
            }
            if (evalCode != CCE_EVAL_EXPORT || version < CCOPTPARAMS_VERSION) return (0, false);
            if (nKeys != 1) return (0, false); // sanity cap
            nextOffset += uint32(op); // skip all header data bytes

            // Step 6: skip n key pushes (each a direct push, opcode 0x01-0x4b).
            // Key types (PKH/ID/SH/PK) are always ≤75 bytes, so PUSHDATA1/2 is unexpected.

            assembly { op := mload(add(firstObj, nextOffset)) }
            nextOffset++;
            if (op < 0x01 || op > 0x4b) return (0, false);
            nextOffset += uint32(op);

        }

        // Step 7: CCE data push (PUSHDATA1 or PUSHDATA2), canonical length enforced.
        // dOff = assembly-offset of first CCE byte (CCE.nVersion[0]).
        uint32 dOff;
        {
            uint8 lenLo;
            assembly { op := mload(add(firstObj, nextOffset)) }
            nextOffset++;
            if (op == SCRIPT_OP_PUSHDATA1) {
                assembly { lenLo := mload(add(firstObj, nextOffset)) }
                if (lenLo <= 75) return (0, false); // non-canonical
                nextOffset += 1;
            } else if (op == SCRIPT_OP_PUSHDATA2) {
                uint8 lenHi;
                assembly {
                    lenLo := mload(add(firstObj, nextOffset))
                    lenHi := mload(add(firstObj, add(nextOffset, 1)))
                }
                if (uint32(lenLo) | (uint32(lenHi) << 8) <= 255) return (0, false); // non-canonical
                nextOffset += 2;
            } else {
                return (0, false);
            }
            dOff = nextOffset;            
        }
        // check there is enough data left in the script for the CCE fields
        require(firstObj.length >= dOff + CCE_FIELDS_LENGTH, "Script too short for CCE fields");

        // _readCCEFields expects nextOffset = dOff + 3, so that:
        //   data[nextOffset-4..nextOffset-3] = CCE.nVersion LE
        //   data[nextOffset-2..nextOffset-1] = CCE.flags    LE
        nextOffset = dOff + 3;
        return (nextOffset, true);
    }
