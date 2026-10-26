    function receiveToken(
        uint256 normalizedAmount,
        uint256 _nonce,
        uint32 sourceChain,
        bytes32 destinationToken,
        bytes32 recipient,
        address swapAddr,
        address tokenMessengersAddr,
        uint256 minSwapAmount
    ) external {
        require(tokenMessengers[tokenMessengersAddr], "No tokenMessengers registered");

        address recipientAddr = address(uint160(uint256(recipient)));
        require(relayers[msg.sender] || msg.sender == recipientAddr, "Unauthorized relayer");
        address intermediaryToken = ITokenMessenger(tokenMessengersAddr).token();
        bytes32 messageHash =
            _calculateMessageHash(_nonce, recipient, destinationToken, normalizedAmount, sourceChain, CHAIN_ID);
        require(!usedMessages[messageHash], "Message already used");

        uint256 receivedAmount = ITokenMessenger(tokenMessengersAddr).receivedTokenAmount(messageHash);
        require(receivedAmount > 0, "Message not received");

        usedMessages[messageHash] = true;

        uint256 actualAmount = _denormalize(normalizedAmount, _getDecimals(intermediaryToken));

        uint256 fee = (actualAmount * feeBp) / BP_DENOMINATOR;
        uint256 amountAfterFee = actualAmount - fee;

        withdrawableAmount[intermediaryToken] += (receivedAmount - amountAfterFee);

        address destTokenAddr = address(uint160(uint256(destinationToken)));

        uint256 amountOut = amountAfterFee;

        if (intermediaryToken != destTokenAddr) {
            require(swaps[swapAddr], "No swap registered");

            IERC20(intermediaryToken).safeTransfer(swapAddr, amountAfterFee);
            amountOut =
                ISwap(swapAddr).swap(amountAfterFee, minSwapAmount, recipientAddr, intermediaryToken, destTokenAddr);
        } else {
            if (destTokenAddr == ETH_MARKER) {
                (bool success,) = recipientAddr.call{value: amountAfterFee}("");
                require(success, "ETH transfer failed");
            } else {
                IERC20(intermediaryToken).safeTransfer(recipientAddr, amountAfterFee);
            }
        }

        emit TokenReceived(
            normalizedAmount,
            fee,
            amountOut,
            sourceChain,
            CHAIN_ID,
            destinationToken,
            recipient,
            intermediaryToken,
            _nonce,
            messageHash,
            swapAddr,
            tokenMessengersAddr
        );
    }

