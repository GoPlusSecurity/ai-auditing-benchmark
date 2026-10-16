    function _exchangeLBT2ERC20(
        uint256 bondGroupID,
        bytes32 erc20PoolID,
        uint256 LBTAmount
    ) internal isExistentPool(erc20PoolID) returns (uint256 ERC20Amount) {
        bytes32 lbtID;
        bytes32 sbtID;
        {
            (bytes32[] memory bonds, ) = _bondMakerContract.getBondGroup(bondGroupID);
            require(bonds.length == 2, "the bond group must include only 2 types of bond.");
            lbtID = bonds[1];
            sbtID = bonds[0];
        }

        ERC20 bondToken;
        uint256 maturity;
        {
            address contractAddress;
            (contractAddress, maturity, , ) = _bondMakerContract.getBond(lbtID);
            require(contractAddress != address(0), "the bond is not registered");
            bondToken = ERC20(contractAddress);
        }

        ERC20 token;
        {
            PoolInfo memory pool = poolMap[erc20PoolID];
            require(!pool.isLBTSellPool, "This pool is not for buying LBT");
            token = pool.ERC20Address;
        }

        uint256 volumeE8;
        {
            (uint256 rateE8, uint256 lbtPriceE8, , ) = _calcRateLBT2ERC20(
                sbtID,
                erc20PoolID,
                maturity
            );
            require(rateE8 != 0, "exchange rate included spread must be non-zero");
            ERC20Amount = _applyDecimalGap(LBTAmount.mul(rateE8), bondToken, token).div(10**8);
            require(ERC20Amount != 0, "must transfer non-zero token amount");
            volumeE8 = lbtPriceE8.mul(LBTAmount).div(10**uint256(bondToken.decimals()));
            volumeE8 = _calcUsdVolume(volumeE8);
        }

        require(
            token.transferFrom(deployer[erc20PoolID], msg.sender, ERC20Amount),
            "fail to transfer ERC20 token"
        );
        require(
            bondToken.transferFrom(msg.sender, deployer[erc20PoolID], LBTAmount),
            "fail to transfer LBT"
        );

        emit LogLBTERC20TokenSwap(
            erc20PoolID,
            msg.sender,
            bondGroupID,
            volumeE8,
            LBTAmount,
            ERC20Amount
        );
    }
