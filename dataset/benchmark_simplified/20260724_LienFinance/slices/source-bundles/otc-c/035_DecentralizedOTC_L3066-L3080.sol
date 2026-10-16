    function exchangeLBT2ERC20(
        uint256 bondGroupID,
        bytes32 erc20PoolID,
        uint256 LBTAmount,
        uint256 expectedAmount,
        uint256 range
    ) public returns (uint256 ERC20Amount) {
        ERC20Amount = _exchangeLBT2ERC20(bondGroupID, erc20PoolID, LBTAmount);
        if (expectedAmount != 0) {
            require(
                ERC20Amount.mul(1000 + range).div(1000) >= expectedAmount,
                "out of price range"
            );
        }
    }
