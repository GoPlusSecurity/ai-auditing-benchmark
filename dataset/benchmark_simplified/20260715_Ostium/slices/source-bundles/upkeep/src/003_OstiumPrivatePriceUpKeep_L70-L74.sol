    function _onlyRouter() private view {
        if (msg.sender != registry.getContractAddress('priceRouter')) {
            revert NotRouter(msg.sender);
        }
    }
