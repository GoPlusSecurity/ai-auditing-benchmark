    function setReceiveLibrary(
        address _oapp,
        uint32 _eid,
        address _newLib,
        uint256 _gracePeriod
    ) external onlyRegisteredOrDefault(_newLib) isReceiveLib(_newLib) onlySupportedEid(_newLib, _eid) {
        _assertAuthorized(_oapp);

        address oldLib = receiveLibrary[_oapp][_eid];
        // must provide new values
        if (oldLib == _newLib) revert Errors.LZ_SameValue();
        receiveLibrary[_oapp][_eid] = _newLib;
        emit ReceiveLibrarySet(_oapp, _eid, _newLib);

        if (_gracePeriod > 0) {
            // to simplify the logic, we only allow to set timeout if neither the new lib nor old lib is DEFAULT_LIB, which would should read the default timeout configurations
            // (1) if the Oapp wants to fall back to the DEFAULT, then set the newLib to DEFAULT with grace period == 0
            // (2) if the Oapp wants to change to a non DEFAULT from DEFAULT, then set the newLib to 'non-default' with _gracePeriod == 0, then use setReceiveLibraryTimeout() interface
            if (oldLib == DEFAULT_LIB || _newLib == DEFAULT_LIB) revert Errors.LZ_OnlyNonDefaultLib();

            // write to storage
            Timeout memory timeout = Timeout({ lib: oldLib, expiry: block.number + _gracePeriod });
            receiveLibraryTimeout[_oapp][_eid] = timeout;
            emit ReceiveLibraryTimeoutSet(_oapp, _eid, oldLib, timeout.expiry);
        } else {
            delete receiveLibraryTimeout[_oapp][_eid];
            emit ReceiveLibraryTimeoutSet(_oapp, _eid, oldLib, 0);
        }
    }
