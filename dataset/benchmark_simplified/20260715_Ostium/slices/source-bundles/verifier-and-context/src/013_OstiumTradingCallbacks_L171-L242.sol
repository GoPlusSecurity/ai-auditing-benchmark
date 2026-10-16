    function openTradeMarketCallback(IOstiumPriceUpKeep.PriceUpKeepAnswer calldata a) external notDone {
        (IOstiumTradingStorage storageT, IOstiumPairInfos pairInfos, IOstiumPairsStorage pairsStorage) = getContracts();
        (uint256 _block, uint256 wantedPrice, uint256 slippageP, IOstiumTradingStorage.Trade memory trade,) =
            storageT.reqID_pendingMarketOrder(a.orderId);
        IOstiumTradingStorage.BuilderFee memory bf = storageT.getBuilderData(trade.trader, trade.pairIndex, a.orderId);

        isPriceUpKeep(trade.pairIndex);

        if (_block == 0) {
            return;
        }

        TradingCallbacksLib.PriceImpactResult memory result;
        CancelReason cancelReason;

        if (a.price <= 0 || a.bid <= 0 || a.ask <= 0) {
            cancelReason = CancelReason.MARKET_CLOSED;
        } else if (isDayTradeClosed(trade.pairIndex, trade.leverage, a.isDayTradingClosed)) {
            cancelReason = CancelReason.DAY_TRADE_NOT_ALLOWED;
        } else {
            (, uint32 takerFeeP,,,,) = pairInfos.pairOpeningFees(trade.pairIndex);
            uint256 calculatedPostFeeCollateral = TradingCallbacksLib.calculatePostFeeCollateral(
                trade.collateral, trade.leverage, trade.pairIndex, takerFeeP, pairsStorage, bf
            );

            result = TradingCallbacksLib.getDynamicTradePriceImpact(
                a.price, int192(a.ask), int192(a.bid), true, trade, pairInfos, calculatedPostFeeCollateral
            );

            trade.openPrice = result.priceAfterImpact.toUint192();

            cancelReason = TradingCallbacksLib.getOpenTradeMarketCancelReason(
                isPaused,
                wantedPrice,
                slippageP,
                uint192(a.price),
                trade,
                result.priceImpactP,
                IOstiumPairInfos(registry.getContractAddress('pairInfos')),
                pairsStorage,
                storageT
            );
        }

        if (cancelReason == CancelReason.NONE) {
            trade = registerTrade(a.orderId, trade, uint192(a.price), bf);

            if (result.isDynamic) {
                _updateDynamicSpreadVolumes(
                    trade.pairIndex, true, trade.buy, trade.collateral, trade.leverage, pairInfos
                );
            }
            uint256 tradeNotional = storageT.getOpenTradeInfo(trade.trader, trade.pairIndex, trade.index).oiNotional;
            IOstiumOpenPnl(registry.getContractAddress('openPnl')).updateAccTotalPnl(
                a.price, trade.openPrice, 0, tradeNotional, trade.pairIndex, trade.buy, true
            );
            IOstiumOpenPnl(registry.getContractAddress('openPnl')).updateAccClosedRollover(trade, 0);
            emit MarketOpenExecuted(a.orderId, trade, result.priceImpactP, tradeNotional);
        } else {
            uint256 oracleFee = pairsStorage.pairOracleFee(trade.pairIndex);
            if (trade.collateral > oracleFee) {
                storageT.transferUsdc(address(storageT), trade.trader, trade.collateral - oracleFee);
            } else {
                oracleFee = trade.collateral;
            }
            storageT.handleOracleFee(oracleFee);

            emit OracleFeeCharged(a.orderId, trade.trader, oracleFee);
            emit MarketOpenCanceled(a.orderId, trade.trader, trade.pairIndex, cancelReason);
        }
        storageT.unregisterPendingMarketOrder(a.orderId, true);
    }
