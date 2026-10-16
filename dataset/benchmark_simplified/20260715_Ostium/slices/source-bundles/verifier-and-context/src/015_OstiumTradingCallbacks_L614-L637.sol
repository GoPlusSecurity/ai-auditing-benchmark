    function unregisterTrade(
        uint256 orderId,
        uint256 tradeId,
        IOstiumTradingStorage.Trade memory trade,
        uint256 usdcSentToTrader,
        uint256 liquidationFee, // PRECISION_6
        uint256 collateralToClose // PRECISION_6
    ) private {
        (IOstiumTradingStorage storageT,, IOstiumPairsStorage pairsStorage) = getContracts();

        TradingCallbacksLib.executeUnregisterTrade(
            trade,
            usdcSentToTrader,
            liquidationFee,
            collateralToClose,
            storageT,
            pairsStorage,
            IOstiumVault(registry.getContractAddress('vault'))
        );

        if (liquidationFee > 0) {
            emit VaultLiqFeeCharged(orderId, tradeId, trade.trader, liquidationFee);
        }
    }
