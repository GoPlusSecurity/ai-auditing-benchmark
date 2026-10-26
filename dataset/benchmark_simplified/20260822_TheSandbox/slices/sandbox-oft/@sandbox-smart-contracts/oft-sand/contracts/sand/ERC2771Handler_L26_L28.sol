    function isTrustedForwarder(address forwarder) public view returns (bool) {
        return forwarder == _trustedForwarder;
    }
