    function _checkStatus(bytes32 _msgHash, Status _expectedStatus) private view {
        if (messageStatus[_msgHash] != _expectedStatus) revert B_INVALID_STATUS();
    }
