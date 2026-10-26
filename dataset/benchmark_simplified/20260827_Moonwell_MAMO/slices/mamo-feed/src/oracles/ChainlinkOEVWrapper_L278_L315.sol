    function setLiquidatorFeeBps(uint16 _liquidatorFeeBps) external onlyOwner {
        require(
            _liquidatorFeeBps <= MAX_BPS,
            "ChainlinkOEVWrapper: liquidator fee cannot be greater than MAX_BPS"
        );
        uint16 oldLiquidatorFeeBps = liquidatorFeeBps;
        liquidatorFeeBps = _liquidatorFeeBps;
        emit LiquidatorFeeBpsChanged(oldLiquidatorFeeBps, _liquidatorFeeBps);
    }

    /**
     * @notice Sets the max round delay in seconds
     * @param _maxRoundDelay The new max round delay (must be > 0)
     */
    function setMaxRoundDelay(uint256 _maxRoundDelay) external onlyOwner {
        require(
            _maxRoundDelay > 0,
            "ChainlinkOEVWrapper: max round delay cannot be zero"
        );
        uint256 oldMaxRoundDelay = maxRoundDelay;
        maxRoundDelay = _maxRoundDelay;
        emit MaxRoundDelayChanged(oldMaxRoundDelay, _maxRoundDelay);
    }

    /**
     * @notice Sets the max number of decrements to search previous rounds
     * @param _maxDecrements The new max decrements (must be > 0)
     */
    function setMaxDecrements(uint256 _maxDecrements) external onlyOwner {
        require(
            _maxDecrements > 0,
            "ChainlinkOEVWrapper: max decrements cannot be zero"
        );
        uint256 oldMaxDecrements = maxDecrements;
        maxDecrements = _maxDecrements;
        emit MaxDecrementsChanged(oldMaxDecrements, _maxDecrements);
    }

