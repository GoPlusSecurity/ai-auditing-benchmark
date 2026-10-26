    function setReleaseContract(address _release) external onlyOwner {
        releaseContract = _release;
        emit ReleaseContractSet(_release);
    }

    function setReleasedMokeHandler(address handler, bool status) external onlyOwner {
        require(handler != address(0), "Invalid handler");
        isReleasedMokeHandler[handler] = status;
        emit ReleasedMokeHandlerSet(handler, status);
    }

    function setCanManageReleasedBalance(address addr, bool status) external onlyOwner {
        require(addr != address(0), "Invalid address");
        canManageReleasedBalance[addr] = status;
        emit CanManageReleasedBalanceSet(addr, status);
    }

    function setXMokePair(address _pair) external onlyOwner {
        xMokePair = _pair;
        emit XMokePairSet(_pair);
    }

