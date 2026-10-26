    function _debit(
        address _from,
        uint256 _amountLD,
        uint256 _minAmountLD,
        uint32 _dstEid
    ) internal virtual override returns (uint256 amountSentLD, uint256 amountReceivedLD) {
        (amountSentLD, amountReceivedLD) = _debitView(_amountLD, _minAmountLD, _dstEid);

        // @dev In NON-default OFT, amountSentLD could be 100, with a 10% fee, the amountReceivedLD amount is 90,
        // therefore amountSentLD CAN differ from amountReceivedLD.

        // @dev Default OFT burns on src.
        _burn(_from, amountSentLD);
    }

    /// @dev Credits tokens to the specified address.
    /// @param _to The address to credit the tokens to.
    /// @param _amountLD The amount of tokens to credit in local decimals.
    /// @dev _srcEid The source chain ID.
    /// @return amountReceivedLD The amount of tokens ACTUALLY received in local decimals.
    function _credit(
        address _to,
        uint256 _amountLD,
        uint32 /*_srcEid*/
    ) internal virtual override returns (uint256 amountReceivedLD) {
        // @dev Default OFT mints on dst.
        _mint(_to, _amountLD);
        // @dev In the case of NON-default OFT, the _amountLD MIGHT not be == amountReceivedLD.
        return _amountLD;
    }

    function _msgSender() internal view override(ERC2771Handler, Context) returns (address sender) {
        return ERC2771Handler._msgSender();
    }
