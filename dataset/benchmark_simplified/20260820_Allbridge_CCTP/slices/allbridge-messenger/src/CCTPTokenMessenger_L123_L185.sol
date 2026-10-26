    function isMessageReceived(bytes32 messageHash) external view override returns (bool) {
        return receivedMessages[messageHash] > 0;
    }

    function receivedTokenAmount(bytes32 messageHash) external view override returns (uint256) {
        return receivedMessages[messageHash];
    }

    function token() external view override returns (address) {
        return TOKEN;
    }

    function getTransactionFeeInNative(uint32 destinationChain)
        public
        view
        override(ChainGasUsage, ITokenMessenger)
        returns (uint256)
    {
        return super.getTransactionFeeInNative(destinationChain);
    }

    // Function to be called by CCTP message relayer
    // It relays the message to MessageTransmitter and marks the messageHash as received
    function receiveCctpMessage(bytes calldata message, bytes calldata attestation) external {
        // CCTP v2 Message Layout:
        // Header:
        // sourceDomain: bytes 4..8
        // destinationCaller: bytes 108..140
        // Body (BurnMessageV2) starts at 148:
        // messageSender (source sender): bytes 100..132 in body -> 248..280 in message
        // hookData: bytes 228.. in body -> 376.. in message

        require(message.length >= 408, "Message too short");

        uint32 sourceDomain = uint32(bytes4(message[4:8]));
        bytes32 destCaller = bytes32(message[108:140]);
        // Body (BurnMessageV2) starts at offset 148
        // amount: bytes 68..100 in body -> 216..248 in message
        uint256 amount = uint256(bytes32(message[216:248]));
        // feeExecuted: bytes 164..196 in body -> 312..344 in message
        uint256 feeExecuted = uint256(bytes32(message[312:344]));
        // sourceSender: bytes 100..132 in body -> 248..280 in message
        bytes32 sourceSender = bytes32(message[248:280]);
        // hookData: bytes 228.. in body -> 376.. in message
        bytes32 messageHash = bytes32(message[376:408]);

        require(destCaller == bytes32(uint256(uint160(address(this)))), "Invalid destination caller");

        uint32 sourceChainId = domainToChainId[sourceDomain];
        require(sourceChainId != 0, "Unknown source domain");

        require(sourceSender == remoteTokenMessengers[sourceChainId], "Invalid remote sender");

        // Relay to MessageTransmitter
        bool success = IMessageTransmitter(MESSAGE_TRANSMITTER).receiveMessage(message, attestation);
        require(success, "CCTP receiveMessage failed");

        uint256 receivedAmount = amount - feeExecuted;

        receivedMessages[messageHash] = receivedAmount;
        emit MessageReceived(messageHash);
    }

