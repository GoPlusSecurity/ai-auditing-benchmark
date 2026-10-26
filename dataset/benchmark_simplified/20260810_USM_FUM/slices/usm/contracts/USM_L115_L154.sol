    function fund(address to, uint minFumOut)
        external payable override
        returns (uint fumOut)
    {
        fumOut = _fundFum(to, minFumOut);
    }

    /**
     * @notice Defunds the pool by redeeming FUM in exchange for equivalent ETH from the pool.
     * @param to address to send the ETH to.
     * @param fumToBurn Amount of FUM to burn.
     * @param minEthOut Minimum accepted ETH for a successful defund.
     */
    function defund(address payable to, uint fumToBurn, uint minEthOut)
        external override
        onlyAfterPrefund
        returns (uint ethOut)
    {
        ethOut = _defundFum(msg.sender, to, fumToBurn, minEthOut);
    }

    /**
     * @notice Defunds the pool by redeeming FUM in exchange for equivalent ETH from the pool.
     * @param from address to deduct the FUM from.
     * @param to address to send the ETH to.
     * @param fumToBurn Amount of FUM to burn.
     * @param minEthOut Minimum accepted ETH for a successful defund.
     */
    function defundFrom(address from, address payable to, uint fumToBurn, uint minEthOut)
        external override
        onlyAfterPrefund
        returns (uint ethOut)
    {
        require(msg.sender == address(fum), "Only FUM");
        ethOut = _defundFum(from, to, fumToBurn, minEthOut);
    }

    /**
     * @notice If anyone sends ETH here, assume they intend it as a `mint`.  If decimals 8 to 11 (inclusive) of the amount of
     * ETH received are `0000`, then the next 7 will be parsed as the minimum number of USM accepted per input ETH, with the
