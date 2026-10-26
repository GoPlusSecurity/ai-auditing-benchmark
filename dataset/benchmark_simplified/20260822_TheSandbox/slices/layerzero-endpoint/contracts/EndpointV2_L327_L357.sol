    function setDelegate(address _delegate) external {
        delegates[msg.sender] = _delegate;
        emit DelegateSet(msg.sender, _delegate);
    }

    // ========================= Internal =========================
    function _initializable(
        Origin calldata _origin,
        address _receiver,
        uint64 _lazyInboundNonce
    ) internal view returns (bool) {
        return
            _lazyInboundNonce > 0 || // allowInitializePath already checked
            ILayerZeroReceiver(_receiver).allowInitializePath(_origin);
    }

    /// @dev bytes(0) payloadHash can never be submitted
    function _verifiable(
        Origin calldata _origin,
        address _receiver,
        uint64 _lazyInboundNonce
    ) internal view returns (bool) {
        return
            _origin.nonce > _lazyInboundNonce || // either initializing an empty slot or reverifying
            inboundPayloadHash[_receiver][_origin.srcEid][_origin.sender][_origin.nonce] != EMPTY_PAYLOAD_HASH; // only allow reverifying if it hasn't been executed
    }

    /// @dev assert the caller to either be the oapp or the delegate
    function _assertAuthorized(address _oapp) internal view override(MessagingChannel, MessageLibManager) {
        if (msg.sender != _oapp && msg.sender != delegates[_oapp]) revert Errors.LZ_Unauthorized();
    }
