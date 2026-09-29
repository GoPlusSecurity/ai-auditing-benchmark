    function retryMessage(
        Message calldata _message,
        bool _isLastAttempt
    )
        external
        sameChain(_message.destChainId)
        diffChain(_message.srcChainId)
        whenNotPaused
        nonReentrant
    {
        bytes32 msgHash = hashMessage(_message);
        _checkStatus(msgHash, Status.RETRIABLE);

        bool succeeded;
        if (_unableToInvokeMessageCall(_message, signalService)) {
            succeeded = _message.destOwner.sendEther(_message.value, _SEND_ETHER_GAS_LIMIT, "");
        } else {
            if ((_message.gasLimit == 0 || _isLastAttempt) && msg.sender != _message.destOwner) {
                revert B_PERMISSION_DENIED();
            }

            // Attempt to invoke the messageCall.
            succeeded = _invokeMessageCall(_message, msgHash, gasleft(), false);
        }

        if (succeeded) {
            _updateMessageStatus(msgHash, Status.DONE);
        } else if (_isLastAttempt) {
            _updateMessageStatus(msgHash, Status.FAILED);

            signalService.sendSignal(signalForFailedMessage(msgHash));
        } else {
            revert B_RETRY_FAILED();
        }
    }
