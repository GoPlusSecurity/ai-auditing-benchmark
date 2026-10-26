    function _assertAtLeastOneDVN(UlnConfig memory _config) private pure {
        if (_config.requiredDVNCount == 0 && _config.optionalDVNThreshold == 0) revert LZ_ULN_AtLeastOneDVN();
    }

    /// @dev this private function is used in both setDefaultUlnConfigs and setUlnConfig
    function _setConfig(address _oapp, uint32 _eid, UlnConfig memory _param) private {
        // @dev required dvns
        // if dvnCount == NONE, dvns list must be empty
        // if dvnCount == DEFAULT, dvn list must be empty
        // otherwise, dvnList.length == dvnCount and assert the list is valid
        if (_param.requiredDVNCount == NIL_DVN_COUNT || _param.requiredDVNCount == DEFAULT) {
            if (_param.requiredDVNs.length != 0) revert LZ_ULN_InvalidRequiredDVNCount();
        } else {
            if (_param.requiredDVNs.length != _param.requiredDVNCount || _param.requiredDVNCount > MAX_COUNT)
                revert LZ_ULN_InvalidRequiredDVNCount();
            _assertNoDuplicates(_param.requiredDVNs);
        }

        // @dev optional dvns
        // if optionalDVNCount == NONE, optionalDVNs list must be empty and threshold must be 0
        // if optionalDVNCount == DEFAULT, optionalDVNs list must be empty and threshold must be 0
        // otherwise, optionalDVNs.length == optionalDVNCount, threshold > 0 && threshold <= optionalDVNCount and assert the list is valid

        // example use case: an oapp uses the DEFAULT 'required' but
        //     a) use a custom 1/1 dvn (practically a required dvn), or
        //     b) use a custom 2/3 dvn
        if (_param.optionalDVNCount == NIL_DVN_COUNT || _param.optionalDVNCount == DEFAULT) {
            if (_param.optionalDVNs.length != 0) revert LZ_ULN_InvalidOptionalDVNCount();
            if (_param.optionalDVNThreshold != 0) revert LZ_ULN_InvalidOptionalDVNThreshold();
        } else {
            if (_param.optionalDVNs.length != _param.optionalDVNCount || _param.optionalDVNCount > MAX_COUNT)
                revert LZ_ULN_InvalidOptionalDVNCount();
            if (_param.optionalDVNThreshold == 0 || _param.optionalDVNThreshold > _param.optionalDVNCount)
                revert LZ_ULN_InvalidOptionalDVNThreshold();
            _assertNoDuplicates(_param.optionalDVNs);
        }
        // don't assert valid count here, as it needs to be validated along side default config

        ulnConfigs[_oapp][_eid] = _param;
    }

    function _assertNoDuplicates(address[] memory _dvns) private pure {
        address lastDVN = address(0);
        for (uint256 i = 0; i < _dvns.length; i++) {
            address dvn = _dvns[i];
            if (dvn <= lastDVN) revert LZ_ULN_Unsorted(); // to ensure no duplicates
            lastDVN = dvn;
        }
    }
