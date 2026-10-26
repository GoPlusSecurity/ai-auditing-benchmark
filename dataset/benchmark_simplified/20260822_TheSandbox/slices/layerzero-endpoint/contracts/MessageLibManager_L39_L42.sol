    modifier onlyRegistered(address _lib) {
        if (!isRegisteredLibrary[_lib]) revert Errors.LZ_OnlyRegisteredLib();
        _;
    }
