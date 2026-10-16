    function _getEffectiveDecayRate(uint256 buyVolume, uint256 sellVolume, uint128 decayRate, uint256 netVolThreshold)
        internal
        pure
        returns (uint128)
    {
        if (netVolThreshold == 0) {
            return decayRate * PRECISION_18 / MAX_DECAY_FACTOR;
        }
        uint256 absNetVol = buyVolume > sellVolume ? buyVolume - sellVolume : sellVolume - buyVolume;

        uint256 factor = PRECISION_18;
        if (absNetVol > netVolThreshold) {
            uint256 ratio = absNetVol * PRECISION_18 / netVolThreshold;
            factor = ratio > MAX_DECAY_FACTOR ? MAX_DECAY_FACTOR : ratio;
        }

        return uint128(decayRate * PRECISION_18 / factor);
    }
