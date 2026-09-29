    function _invokeMessageCall(
        Message calldata _message,
        bytes32 _msgHash,
        uint256 _gasLimit,
        bool _shouldCheckForwardedGas
    )
        private
        returns (bool success_)
    {
        assert(_message.from != address(this));

        if (_message.value == 0 && _message.data.length == 0) return true;

        if (_gasLimit == 0) return false;

        _storeContext(_msgHash, _message.from, _message.srcChainId);

        address to = _message.to;
        uint256 value = _message.value;
        bytes memory data = _message.data;
        uint256 gasLeft;

        assembly {
            success_ := call(_gasLimit, to, value, add(data, 0x20), mload(data), 0, 0)
            gasLeft := gas()
        }

        if (_shouldCheckForwardedGas) {
            _checkForwardedGas(gasLeft, _gasLimit);
        }
        _storeContext(bytes32(_PLACEHOLDER), address(uint160(_PLACEHOLDER)), uint64(_PLACEHOLDER));
    }
