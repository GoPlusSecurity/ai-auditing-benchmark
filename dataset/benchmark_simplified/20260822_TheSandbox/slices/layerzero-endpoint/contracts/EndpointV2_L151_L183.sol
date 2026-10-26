    function verify(Origin calldata _origin, address _receiver, bytes32 _payloadHash) external {
        if (!isValidReceiveLibrary(_receiver, _origin.srcEid, msg.sender)) revert Errors.LZ_InvalidReceiveLibrary();

        uint64 lazyNonce = lazyInboundNonce[_receiver][_origin.srcEid][_origin.sender];
        if (!_initializable(_origin, _receiver, lazyNonce)) revert Errors.LZ_PathNotInitializable();
        if (!_verifiable(_origin, _receiver, lazyNonce)) revert Errors.LZ_PathNotVerifiable();

        // insert the message into the message channel
        _inbound(_receiver, _origin.srcEid, _origin.sender, _origin.nonce, _payloadHash);
        emit PacketVerified(_origin, _receiver, _payloadHash);
    }

    /// @dev MESSAGING STEP 3 - the last step
    /// @dev execute a verified message to the designated receiver
    /// @dev the execution provides the execution context (caller, extraData) to the receiver. the receiver can optionally assert the caller and validate the untrusted extraData
    /// @dev cant reentrant because the payload is cleared before execution
    /// @param _origin the origin of the message
    /// @param _receiver the receiver of the message
    /// @param _guid the guid of the message
    /// @param _message the message
    /// @param _extraData the extra data provided by the executor. this data is untrusted and should be validated.
    function lzReceive(
        Origin calldata _origin,
        address _receiver,
        bytes32 _guid,
        bytes calldata _message,
        bytes calldata _extraData
    ) external payable {
        // clear the payload first to prevent reentrancy, and then execute the message
        _clearPayload(_receiver, _origin.srcEid, _origin.sender, _origin.nonce, abi.encodePacked(_guid, _message));
        ILayerZeroReceiver(_receiver).lzReceive{ value: msg.value }(_origin, _guid, _message, msg.sender, _extraData);
        emit PacketDelivered(_origin, _receiver);
    }
