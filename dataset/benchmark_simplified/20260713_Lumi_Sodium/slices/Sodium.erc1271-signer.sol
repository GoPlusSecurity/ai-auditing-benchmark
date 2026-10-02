    function checkValidSodiumSignature(
        bytes32 _hash,
        bytes calldata _signature
    ) public view returns (bool valid, address signer, address trustee) {
        bytes1 sigType = bytes1(_signature[:1]);
        // {0x01}{signer}{signature}
        if (sigType == 0x01) {
            bytes memory addressBytes = _signature[1:21];
            bytes memory signatureBytes = _signature[21:];
            assembly {
                signer := mload(add(addressBytes, 20))
            }
            valid = SignatureChecker.isValidSignatureNow(
                signer,
                _hash,
                signatureBytes
            );
        // {0x02}{trustee}{signer}{delegateExpires}{signature}{delegateproof}
        } else if (sigType == 0x02) {
            uint64 delegateExpires;
            bytes memory signature;
            bytes memory delegateproof;
            (trustee, signer, delegateExpires, signature, delegateproof) = abi
                .decode(
                    _signature[1:],
                    (address, address, uint64, bytes, bytes)
                );
            if (delegateExpires < block.timestamp) {
                valid = false;
                return (valid, signer, trustee);
            }
            bytes32 dataHash = _hashTypedData(
                keccak256(
                    abi.encode(
                        _DELEGATE_AURH_TYPEHASH,
                        trustee,
                        delegateExpires
                    )
                )
            );
            bool delegateValid = SignatureChecker.isValidSignatureNow(
                signer,
                dataHash,
                delegateproof
            );
            bool trusteeValid = SignatureChecker.isValidSignatureNow(
                trustee,
                _hash,
                signature
            );
            valid = delegateValid && trusteeValid;
        } else {
            valid = false;
        }
    }
}
