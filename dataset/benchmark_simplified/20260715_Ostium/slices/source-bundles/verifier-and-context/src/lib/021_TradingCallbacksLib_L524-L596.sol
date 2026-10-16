    function executeRegisterTrade(
        uint256 tradeId,
        IOstiumTradingStorage.Trade memory trade,
        uint256 latestPrice,
        IOstiumTradingStorage.BuilderFee memory bf,
        uint8 maxSl_P,
        IOstiumTradingStorage storageT,
        IOstiumPairInfos pairInfos,
        IOstiumPairsStorage pairsStorage,
        IOstiumVault vault
    )
        external
        returns (
            IOstiumTradingStorage.Trade memory,
            uint256 reward,
            uint256 vaultReward,
            uint256 oracleFee,
            uint256 builderFee
        )
    {
        uint256 tradeNotional = Math.mulDiv(trade.collateral, trade.leverage, 100, Math.Rounding.Ceil);

        // 2.1 Charge opening fee
        {
            (reward, vaultReward) =
                storageT.handleOpeningFees(trade.pairIndex, latestPrice, tradeNotional, trade.leverage, trade.buy);

            trade.collateral -= reward;

            if (vaultReward > 0) {
                storageT.transferUsdc(address(storageT), address(this), vaultReward);
                vault.distributeReward(vaultReward);
                trade.collateral -= vaultReward;
            }
        }

        oracleFee = pairsStorage.pairOracleFee(trade.pairIndex);
        storageT.handleOracleFee(oracleFee);
        trade.collateral -= oracleFee;

        if (bf.builder != address(0) && bf.builderFee > 0) {
            builderFee = bf.builderFee * tradeNotional / PRECISION_6 / 100;
            storageT.transferUsdc(address(storageT), bf.builder, builderFee);
            trade.collateral -= builderFee;
        }

        // 4. Set trade final details
        trade.index = storageT.firstEmptyTradeIndex(trade.trader, trade.pairIndex);

        trade.tp = correctTp(trade.openPrice, trade.tp, trade.leverage, trade.leverage, trade.buy);
        trade.sl = correctSl(trade.openPrice, trade.sl, trade.leverage, trade.leverage, trade.buy, maxSl_P);

        // 5. Call other contracts
        pairInfos.storeTradeInitialAccFees(tradeId, trade.trader, trade.pairIndex, trade.index, trade.buy);
        pairsStorage.updateGroupCollateral(trade.pairIndex, trade.collateral, trade.buy, true);

        // 6. Store final trade in storage contract
        uint32 currTimestamp = block.timestamp.toUint32();
        storageT.storeTrade(
            trade,
            IOstiumTradingStorage.TradeInfo(
                tradeId,
                trade.collateral * uint256(1e12) * trade.leverage / 100 * PRECISION_18 / trade.openPrice,
                trade.leverage,
                currTimestamp,
                currTimestamp,
                currTimestamp,
                false
            )
        );

        return (trade, reward, vaultReward, oracleFee, builderFee);
    }
