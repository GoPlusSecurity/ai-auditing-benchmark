    function _inbound(
        address _receiver,
        uint32 _srcEid,
        bytes32 _sender,
        uint64 _nonce,
        bytes32 _payloadHash
    ) internal {
        if (_payloadHash == EMPTY_PAYLOAD_HASH) revert Errors.LZ_InvalidPayloadHash();
        inboundPayloadHash[_receiver][_srcEid][_sender][_nonce] = _payloadHash;
    }
