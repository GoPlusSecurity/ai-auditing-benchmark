    function _clearPayload(
        address _receiver,
        uint32 _srcEid,
        bytes32 _sender,
        uint64 _nonce,
        bytes memory _payload
    ) internal returns (bytes32 actualHash) {
        uint64 currentNonce = lazyInboundNonce[_receiver][_srcEid][_sender];
        if (_nonce > currentNonce) {
            unchecked {
                // try to lazily update the inboundNonce till the _nonce
                for (uint64 i = currentNonce + 1; i <= _nonce; ++i) {
                    if (!_hasPayloadHash(_receiver, _srcEid, _sender, i)) revert Errors.LZ_InvalidNonce(i);
                }
                lazyInboundNonce[_receiver][_srcEid][_sender] = _nonce;
            }
        }

        // check the hash of the payload to verify the executor has given the proper payload that has been verified
        actualHash = keccak256(_payload);
        bytes32 expectedHash = inboundPayloadHash[_receiver][_srcEid][_sender][_nonce];
        if (expectedHash != actualHash) revert Errors.LZ_PayloadHashNotFound(expectedHash, actualHash);

        // remove it from the storage
        delete inboundPayloadHash[_receiver][_srcEid][_sender][_nonce];
    }
