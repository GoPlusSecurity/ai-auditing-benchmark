    function executeUnregisterTrade(
        IOstiumTradingStorage.Trade memory trade,
        uint256 usdcSentToTrader,
        uint256 liquidationFee,
        uint256 collateralToClose,
        IOstiumTradingStorage storageT,
        IOstiumPairsStorage pairsStorage,
        IOstiumVault vault
    ) external {
        pairsStorage.updateGroupCollateral(trade.pairIndex, collateralToClose, trade.buy, false);

        // 3.1 Unregister trade
        storageT.unregisterTrade(trade.trader, trade.pairIndex, trade.index, collateralToClose);

        // 3 USDC vault reward
        if (liquidationFee > 0) {
            storageT.transferUsdc(address(storageT), address(this), liquidationFee);
            vault.receiveAssets(liquidationFee, trade.trader);
        }

        // 4 Take USDC from vault if winning trade
        // or send USDC to vault if losing trade
        uint256 usdcLeftInStorage = collateralToClose - liquidationFee;

        if (usdcSentToTrader > usdcLeftInStorage) {
            vault.sendAssets(usdcSentToTrader - usdcLeftInStorage, trade.trader);
            storageT.transferUsdc(address(storageT), trade.trader, usdcLeftInStorage);
        } else {
            uint256 usdcSentToVault = usdcLeftInStorage - usdcSentToTrader;
            storageT.transferUsdc(address(storageT), address(this), usdcSentToVault);
            vault.receiveAssets(usdcSentToVault, trade.trader);
            if (usdcSentToTrader > 0) storageT.transferUsdc(address(storageT), trade.trader, usdcSentToTrader);
        }
    }
