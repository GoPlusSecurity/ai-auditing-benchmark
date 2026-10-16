   function readCompactSizeLE(bytes memory incoming, uint256 offset) public pure returns(uint64 v, uint retidx) {

        uint8 oneByte;
        assembly {
            oneByte := mload(add(incoming, offset))
        }
        offset++;
        if (oneByte < 253)
        {
            return (uint64(oneByte), offset);
        }
        else if (oneByte == 253)
        {
            offset += 1; // skip marker(1) + align so 2-byte value is in mload LSBs
            uint16 twoByte;
            assembly {
                twoByte := mload(add(incoming, offset))
            }
            uint16 value16 = ((twoByte << 8) & 0xffff) | twoByte >> 8;
            require(value16 >= 253, "Non-canonical compact-size");
            return (value16, offset + 1);
        }
        else if (oneByte == 254)
        {
            offset += 3; // skip marker(1) + align so 4-byte value is in mload LSBs
            uint32 fourByte;
            assembly {
                fourByte := mload(add(incoming, offset))
            }
            uint32 value32 = serializeUint32(fourByte);
            require(value32 >= 65536, "Non-canonical compact-size");
            return (value32, offset + 1);
        }
        else
        {
            revert("Compact-size too large");
        }
    }
