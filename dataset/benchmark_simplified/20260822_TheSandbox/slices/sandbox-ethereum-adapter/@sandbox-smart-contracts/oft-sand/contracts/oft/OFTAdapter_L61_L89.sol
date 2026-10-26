    function _debit(
        address _from,
        uint256 _amountLD,
        uint256 _minAmountLD,
        uint32 _dstEid
    ) internal virtual override returns (uint256 amountSentLD, uint256 amountReceivedLD) {
        (amountSentLD, amountReceivedLD) = _debitView(_amountLD, _minAmountLD, _dstEid);
        // @dev Lock tokens by moving them into this contract from the caller.
        innerToken.safeTransferFrom(_from, address(this), amountSentLD);
    }

    /// @dev Credits tokens to the specified address.
    /// @param _to The address to credit the tokens to.
    /// @param _amountLD The amount of tokens to credit in local decimals.
    /// @dev _srcEid The source chain ID.
    /// @return amountReceivedLD The amount of tokens ACTUALLY received in local decimals.
    /// @dev WARNING: The default OFTAdapter implementation assumes LOSSLESS transfers, ie. 1 token in, 1 token out.
    /// IF the 'innerToken' applies something like a transfer fee, the default will NOT work...
    /// a pre/post balance check will need to be done to calculate the amountReceivedLD.
    function _credit(
        address _to,
        uint256 _amountLD,
        uint32 /*_srcEid*/
    ) internal virtual override returns (uint256 amountReceivedLD) {
        // @dev Unlock the tokens and transfer to the recipient.
        innerToken.safeTransfer(_to, _amountLD);
        // @dev In the case of NON-default OFTAdapter, the amountLD MIGHT not be == amountReceivedLD.
        return _amountLD;
    }
