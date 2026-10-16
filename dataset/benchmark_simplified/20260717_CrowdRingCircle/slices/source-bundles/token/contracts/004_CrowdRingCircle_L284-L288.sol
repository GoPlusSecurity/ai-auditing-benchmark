    function setDexPair(address pair, bool status) external onlyOwner {
        if (pair == address(0)) revert ZeroAddress();
        isDexPair[pair] = status;
        emit DexPairUpdated(pair, status);
    }
