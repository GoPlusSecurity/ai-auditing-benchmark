    function readVarint(bytes memory buf, uint idx) public pure returns (uint64 v, uint retidx) {
        uint8 b;
    
        assembly {
            let end := add(idx, 10)
            let i := idx
            retidx := add(idx, 1)
            for {} lt(i, end) {} {
                b := mload(add(buf, retidx))
                i := add(i, 1)
                v := or(shl(7, v), and(b, 0x7f))
                if iszero(eq(and(b, 0x80), 0x80)) {
                    break
                }
                v := add(v, 1)
                retidx := add(retidx, 1)
            }
        }

    }
