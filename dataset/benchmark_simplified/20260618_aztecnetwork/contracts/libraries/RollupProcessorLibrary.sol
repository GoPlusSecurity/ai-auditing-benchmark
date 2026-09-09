// SPDX-License-Identifier: GPL-2.0-only

pragma solidity >=0.6.10 <0.8.0;

library RollupProcessorLibrary {
    function validateUnpackedSignature(
        bytes32 digest,
        bytes memory signature,
        address signer
    ) internal view {
        bool result;
        address recoveredSigner = address(0x0);
        require(signer != address(0x0), 'validateSignature: ZERO_ADDRESS');

        bytes32 message;
        assembly {
            mstore(0, "\x19Ethereum Signed Message:\n32")
            mstore(28, digest)
            message := keccak256(0, 60)
        }
        assembly {

            let byteLength := mload(signature)

            mstore(signature, message)

            let v := mload(add(signature, 0x60))
            let s := mload(add(signature, 0x40))

            mstore(add(signature, 0x60), s)

            mstore(add(signature, 0x40), mload(add(signature, 0x20)))

            mstore(add(signature, 0x20), v)
            result := and(
                and(

                    lt(s, 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A1),
                    and(

                        eq(byteLength, 0x60),

                        or(eq(v, 27), eq(v, 28))
                    )
                ),

                staticcall(gas(), 0x01, signature, 0x80, signature, 0x20)
            )

            switch eq(message, mload(signature))
            case 0 {
                recoveredSigner := mload(signature)
            }
            mstore(signature, byteLength)

            result := and(result, not(iszero(recoveredSigner)))
        }

        require(result, 'validateSignature: signature recovery failed');
        require(recoveredSigner == signer, 'validateSignature: INVALID_SIGNATURE');
    }
}
