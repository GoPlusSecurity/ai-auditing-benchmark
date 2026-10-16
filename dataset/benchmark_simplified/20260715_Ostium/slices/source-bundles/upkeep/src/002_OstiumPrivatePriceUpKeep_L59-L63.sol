    function _onlyTimelock() private view {
        if (msg.sender != IOwnable(address(registry)).owner()) {
            revert NotTimelock(msg.sender);
        }
    }
