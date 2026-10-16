    function _exchangeBondToErc20(
        address buyer,
        bytes32 bondID,
        bytes32 poolID,
        uint256 bondAmount
    ) internal returns (uint256 swapPairAmount) {
        (
            address seller,
            ERC20 swapPairToken,
            ,
            ,
            ,
            bool isBondSale
        ) = _getVsErc20Pool(poolID);
        require(!isBondSale, "This pool is not for buying bond");

        (ERC20 bondToken, , , ) = _getBond(_bondMakerContract, bondID);
        require(address(bondToken) != address(0), "the bond is not registered");

        uint256 volumeE8;
        {
            (uint256 rateE8, uint256 bondPriceE8, , ) = _calcRateBondToErc20(
                bondID,
                poolID
            );
            require(
                rateE8 > MIN_EXCHANGE_RATE_E8,
                "exchange rate is too small"
            );
            require(
                rateE8 < MAX_EXCHANGE_RATE_E8,
                "exchange rate is too large"
            );
            uint8 decimalsOfSwapPair = swapPairToken.decimals();
            swapPairAmount = _applyDecimalGap(
                bondAmount.mul(rateE8),
                DECIMALS_OF_BOND + 8,
                decimalsOfSwapPair
            );
            require(swapPairAmount != 0, "must transfer non-zero token amount");
            volumeE8 = bondPriceE8.mul(bondAmount).div(
                10**uint256(DECIMALS_OF_BOND)
            );
        }

        require(
            bondToken.transferFrom(buyer, seller, bondAmount),
            "fail to transfer bonds"
        );
        swapPairToken.safeTransferFrom(seller, buyer, swapPairAmount);

        emit LogExchangeBondToErc20(
            buyer,
            bondID,
            poolID,
            bondAmount,
            swapPairAmount,
            volumeE8
        );
    }
