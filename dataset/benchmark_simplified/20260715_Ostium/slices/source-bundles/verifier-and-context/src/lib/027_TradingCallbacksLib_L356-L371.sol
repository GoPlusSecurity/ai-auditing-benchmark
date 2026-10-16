    function _decayVolumeWithPade(uint256 volume, uint32 decayInterval, uint128 decayRate)
        internal
        pure
        returns (uint256 decayedVolume)
    {
        if (decayInterval == 0) {
            return volume;
        }

        uint256 decayFactor_half = uint256(decayRate) * decayInterval / 2;
        uint256 numerator = PRECISION_18 > decayFactor_half ? PRECISION_18 - decayFactor_half : 0;
        uint256 denominator = PRECISION_18 + decayFactor_half;
        uint256 decayMultiplier = numerator * PRECISION_18 / denominator;

        return uint128(uint256(volume) * decayMultiplier / PRECISION_18);
    }
