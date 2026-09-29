    function _updateMessageStatus(bytes32 _msgHash, Status _status) private {
        if (messageStatus[_msgHash] == _status) revert B_INVALID_STATUS();
        messageStatus[_msgHash] = _status;
        emit MessageStatusChanged(_msgHash, _status);
    }
