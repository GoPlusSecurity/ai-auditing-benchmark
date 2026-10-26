    function setConfig(address _oapp, SetConfigParam[] calldata _params) external override onlyEndpoint {
        for (uint256 i = 0; i < _params.length; i++) {
            SetConfigParam calldata param = _params[i];
            _assertSupportedEid(param.eid);
            if (param.configType == CONFIG_TYPE_ULN) {
                _setUlnConfig(param.eid, _oapp, abi.decode(param.config, (UlnConfig)));
            } else {
                revert LZ_ULN_InvalidConfigType(param.configType);
            }
        }
    }

    // ============================ External ===================================

    /// @dev dont need to check endpoint verifiable here to save gas, as it will reverts if not verifiable.
    function commitVerification(bytes calldata _packetHeader, bytes32 _payloadHash) external {
        _assertHeader(_packetHeader, localEid);

        // cache these values to save gas
        address receiver = _packetHeader.receiverB20();
        uint32 srcEid = _packetHeader.srcEid();

        UlnConfig memory config = getUlnConfig(receiver, srcEid);
        _verifyAndReclaimStorage(config, keccak256(_packetHeader), _payloadHash);

        Origin memory origin = Origin(srcEid, _packetHeader.sender(), _packetHeader.nonce());
        // endpoint will revert if nonce <= lazyInboundNonce
        ILayerZeroEndpointV2(endpoint).verify(origin, receiver, _payloadHash);
    }

    /// @dev for dvn to verify the payload
    function verify(bytes calldata _packetHeader, bytes32 _payloadHash, uint64 _confirmations) external {
        _verify(_packetHeader, _payloadHash, _confirmations);
    }
