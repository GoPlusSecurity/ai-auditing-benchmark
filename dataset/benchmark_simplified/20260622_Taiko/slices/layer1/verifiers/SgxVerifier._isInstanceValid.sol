    function _isInstanceValid(uint256 id, address instance) private view returns (bool) {
        require(instance != address(0), SGX_INVALID_INSTANCE());
        require(instance == instances[id].addr, SGX_INVALID_INSTANCE());
        return instances[id].validSince <= block.timestamp
            && block.timestamp <= instances[id].validSince + INSTANCE_EXPIRY;
    }
