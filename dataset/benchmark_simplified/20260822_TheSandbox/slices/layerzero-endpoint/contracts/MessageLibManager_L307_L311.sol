    function setConfig(address _oapp, address _lib, SetConfigParam[] calldata _params) external onlyRegistered(_lib) {
        _assertAuthorized(_oapp);

        IMessageLib(_lib).setConfig(_oapp, _params);
    }
