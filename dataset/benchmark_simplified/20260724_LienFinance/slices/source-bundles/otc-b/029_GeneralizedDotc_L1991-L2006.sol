    function exchangeBondToErc20(
        bytes32 bondID,
        bytes32 poolID,
        uint256 bondAmount,
        uint256 expectedAmount,
        uint256 range
    ) external returns (uint256 swapPairAmount) {
        swapPairAmount = _exchangeBondToErc20(
            msg.sender,
            bondID,
            poolID,
            bondAmount
        );
        // assert(swapPairAmount != 0);
        _assertExpectedPriceRange(swapPairAmount, expectedAmount, range);
    }
