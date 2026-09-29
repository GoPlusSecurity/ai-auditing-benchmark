    function _proveSignalReceived(
        ISignalService _signalService,
        bytes32 _signal,
        uint64 _chainId,
        bytes calldata _proof
    )
        private
        returns (uint32 numCacheOps_)
    {
        try _signalService.proveSignalReceived(
            _chainId, resolve(_chainId, LibNames.B_BRIDGE, false), _signal, _proof
        ) returns (
            uint256 numCacheOps
        ) {
            numCacheOps_ = uint32(numCacheOps);
        } catch {
            revert B_SIGNAL_NOT_RECEIVED();
        }
    }
