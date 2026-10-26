    function setPair(address _pair, bool _status) external onlyOwner {
        require(_pair != address(0), "BT: pair cannot be zero address");
        isBuyerWhitelist[_pair] = _status;
        isPair[_pair] = _status;
    }

    function setExcludedFromFee(address account, bool excluded) external onlyOwner {
        isExcludedFromFee[account] = excluded;
        emit WhitelistUpdated(account, excluded);
    }

    function setCanAddLiquid(address account, bool excluded) external onlyOwner {
        canAddLiquid[account] = excluded;
    }

    function setBlacklist(address account, bool blacklisted) external onlyOwner {
        isBlacklisted[account] = blacklisted;
        emit BlacklistUpdated(account, blacklisted);
    }

    function batchSetBlacklist(address[] calldata accounts, bool blacklisted) external onlyOwner {
        for (uint256 i = 0; i < accounts.length; i++) {
            isBlacklisted[accounts[i]] = blacklisted;
            emit BlacklistUpdated(accounts[i], blacklisted);
        }
    }

    function batchSetWhitelist(address[] calldata accounts, bool whitelisted) external onlyOwner {
        for (uint256 i = 0; i < accounts.length; i++) {
            isExcludedFromFee[accounts[i]] = whitelisted;
            emit WhitelistUpdated(accounts[i], whitelisted);
        }
    }

    function setBuyerWhitelist(address account, bool whitelisted) external onlyOwner {
        isBuyerWhitelist[account] = whitelisted;
    }


    function setTradingEnabled(bool enabled) external onlyOwner {
        tradingEnabled = enabled;
    }
