    function _claimBatch(
        address claimer,
        uint128[] calldata tierIds,
        address recipient
    )
        internal
        returns (uint256[] memory)
    {
        require(
            recipient != address(0),
            "Recipient address cannot be zero"
        );

        uint256 n = tierIds.length;
        uint256[] memory claimableArr = new uint256[](n);

        for (uint256 i = 0; i < n;) {
            uint128 tierId = tierIds[i];
            claimableArr[i] = _claim(claimer, tierId, recipient);

            unchecked { ++i; }
        }

        return claimableArr;
    }
