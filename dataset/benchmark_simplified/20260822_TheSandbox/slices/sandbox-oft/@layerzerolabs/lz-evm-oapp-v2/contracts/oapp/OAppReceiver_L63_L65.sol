    function allowInitializePath(Origin calldata origin) public view virtual returns (bool) {
        return peers[origin.srcEid] == origin.sender;
    }
