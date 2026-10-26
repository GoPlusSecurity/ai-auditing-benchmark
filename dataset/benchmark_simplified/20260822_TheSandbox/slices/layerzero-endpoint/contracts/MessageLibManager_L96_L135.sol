    function getReceiveLibrary(address _receiver, uint32 _srcEid) public view returns (address lib, bool isDefault) {
        lib = receiveLibrary[_receiver][_srcEid];
        if (lib == DEFAULT_LIB) {
            lib = defaultReceiveLibrary[_srcEid];
            if (lib == address(0x0)) revert Errors.LZ_DefaultReceiveLibUnavailable();
            isDefault = true;
        }
    }

    /// @dev called when the endpoint checks if the msgLib attempting to verify the msg is the configured msgLib of the Oapp
    /// @dev this check provides the ability for Oapp to lock in a trusted msgLib
    /// @dev it will fist check if the msgLib is the currently configured one. then check if the msgLib is the one in grace period of msgLib versioning upgrade
    function isValidReceiveLibrary(
        address _receiver,
        uint32 _srcEid,
        address _actualReceiveLib
    ) public view returns (bool) {
        // early return true if the _actualReceiveLib is the currently configured one
        (address expectedReceiveLib, bool isDefault) = getReceiveLibrary(_receiver, _srcEid);
        if (_actualReceiveLib == expectedReceiveLib) {
            return true;
        }

        // check the timeout condition otherwise
        // if the Oapp is using defaultReceiveLibrary, use the default Timeout config
        // otherwise, use the Timeout configured by the Oapp
        Timeout memory timeout = isDefault
            ? defaultReceiveLibraryTimeout[_srcEid]
            : receiveLibraryTimeout[_receiver][_srcEid];

        // requires the _actualReceiveLib to be the same as the one in grace period and the grace period has not expired
        // block.number is uint256 so timeout.expiry must > 0, which implies a non-ZERO value
        if (timeout.lib == _actualReceiveLib && timeout.expiry > block.number) {
            // timeout lib set and has not expired
            return true;
        }

        // returns false by default
        return false;
    }
