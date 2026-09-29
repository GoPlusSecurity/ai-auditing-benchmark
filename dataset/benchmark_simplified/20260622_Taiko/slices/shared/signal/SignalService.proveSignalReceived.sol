    function proveSignalReceived(
        uint64 _chainId,
        address _app,
        bytes32 _signal,
        bytes calldata _proof
    )
        external
        virtual
        whenNotPaused
        returns (uint256)
    {
        _verifySignalReceived(_chainId, _app, _signal, _proof);
        _receivedSignals[getSignalSlot(_chainId, _app, _signal)] = true;
        return 0;
    }
