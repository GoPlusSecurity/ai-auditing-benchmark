    function send(
        SendParam calldata _sendParam,
        MessagingFee calldata _fee,
        address _refundAddress
    ) public payable virtual override returns (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt) {
        if (!_enabled) {
            revert SendFunctionDisabled();
        }

        super.send(_sendParam, _fee, _refundAddress);
    }
