    function processMessage(
        Message calldata _message,
        bytes calldata _proof
    )
        external
        whenNotPaused
        nonReentrant
        returns (Status status_, StatusReason reason_)
    {
        uint256 gasStart = gasleft();

        // same as `sameChain(_message.destChainId)` but without stack-too-deep
        if (_message.destChainId != block.chainid) revert B_INVALID_CHAINID();

        // same as `diffChain(_message.srcChainId)` but without stack-too-deep
        if (_message.srcChainId == 0 || _message.srcChainId == block.chainid) {
            revert B_INVALID_CHAINID();
        }

        ProcessingStats memory stats;
        stats.processedByRelayer = msg.sender != _message.destOwner;

        // If the gas limit is set to zero, only the owner can process the message.
        if (stats.processedByRelayer) {
            if (_message.gasLimit == 0) revert B_PERMISSION_DENIED();
            if (_proof.length > RELAYER_MAX_PROOF_BYTES) revert B_PROOF_TOO_LARGE();
        }

        bytes32 msgHash = hashMessage(_message);

        _checkStatus(msgHash, Status.NEW);

        stats.proofSize = uint32(_proof.length);
        stats.numCacheOps =
            _proveSignalReceived(signalService, msgHash, _message.srcChainId, _proof);

        uint256 refundAmount;
        if (_unableToInvokeMessageCall(_message, signalService)) {
            // Handle special addresses and message.data encoded function calldata that don't
            // require or cannot proceed with actual invocation and mark message as DONE
            refundAmount = _message.value;
            status_ = Status.DONE;
            reason_ = StatusReason.INVOCATION_PROHIBITED;
        } else {
            uint256 gasLimit = stats.processedByRelayer ? _invocationGasLimit(_message) : gasleft();

            if (_invokeMessageCall(_message, msgHash, gasLimit, stats.processedByRelayer)) {
                status_ = Status.DONE;
                reason_ = StatusReason.INVOCATION_OK;
            } else {
                status_ = Status.RETRIABLE;
                reason_ = StatusReason.INVOCATION_FAILED;
            }
        }

        if (_message.fee != 0) {
            refundAmount += _message.fee;

            if (stats.processedByRelayer && _message.gasLimit != 0) {
                unchecked {
                    // The relayer (=message processor) needs to get paid from the fee, and below it
                    // the calculation mechanism of that.
                    // The high level overview is: "gasCharged * block.basefee" with some caveat.
                    // Sometimes over or under estimated and it has different reasons:
                    // - a rational relayer shall simulate transactions off-chain so he/she would
                    // exactly know if the txn is profitable or not.
                    // - need to have a buffer/small revenue to the realyer since it consumes
                    // maintenance and infra costs to operate
                    uint256 refund = stats.numCacheOps * _GAS_REFUND_PER_CACHE_OPERATION;
                    // Taking into account the encoded message calldata cost, and can count with 16
                    // gas per bytes (vs. checking each and every byte if zero or non-zero)
                    stats.gasUsedInFeeCalc = uint32(
                        GAS_OVERHEAD + gasStart + _messageCalldataCost(_message.data.length)
                            - gasleft()
                    );

                    uint256 gasCharged = refund.max(stats.gasUsedInFeeCalc) - refund;
                    uint256 maxFee = gasCharged * _message.fee / _message.gasLimit;
                    uint256 baseFee = gasCharged * block.basefee;
                    uint256 fee =
                        (baseFee >= maxFee ? maxFee : (maxFee + baseFee) >> 1).min(_message.fee);

                    refundAmount -= fee;
                    msg.sender.sendEtherAndVerify(fee, _SEND_ETHER_GAS_LIMIT);
                }
            }
        }

        _message.destOwner.sendEtherAndVerify(refundAmount, _SEND_ETHER_GAS_LIMIT);

        _updateMessageStatus(msgHash, status_);
        emit MessageProcessed(msgHash, _message, stats);
    }
