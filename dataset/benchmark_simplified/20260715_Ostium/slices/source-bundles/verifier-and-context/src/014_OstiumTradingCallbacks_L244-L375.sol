    function closeTradeMarketCallback(IOstiumPriceUpKeep.PriceUpKeepAnswer calldata a) external notDone {
        (IOstiumTradingStorage storageT, IOstiumPairInfos pairInfos,) = getContracts();
        (
            uint256 _block,
            uint256 wantedPrice,
            uint256 slippageP,
            IOstiumTradingStorage.Trade memory trade,
            uint16 closePercentage
        ) = storageT.reqID_pendingMarketOrder(a.orderId);

        isPriceUpKeep(trade.pairIndex);

        if (_block == 0) {
            return;
        }

        IOstiumTradingStorage.Trade memory t = storageT.getOpenTrade(trade.trader, trade.pairIndex, trade.index);

        CancelReason cancelReason = t.leverage == 0
            ? CancelReason.NO_TRADE
            : ((a.price <= 0 || a.bid <= 0 || a.ask <= 0) ? CancelReason.MARKET_CLOSED : CancelReason.NONE);

        IOstiumTradingStorage.TradeInfo memory i = storageT.getOpenTradeInfo(t.trader, t.pairIndex, t.index);

        // Validate tradeId matches to prevent execution on replaced trades
        // Skip validation if storedTradeId == 0 (legacy order from before upgrade)
        if (cancelReason == CancelReason.NONE) {
            uint256 storedTradeId = storageT.pendingMarketCloseTradeIds(a.orderId);
            if (storedTradeId != 0 && i.tradeId != storedTradeId) {
                cancelReason = CancelReason.WRONG_TRADE;
            }
        }

        if (cancelReason != CancelReason.NO_TRADE) {
            if (cancelReason == CancelReason.NONE) {
                uint256 collateralToClose = t.collateral * closePercentage / 100e2;

                (
                    TradingCallbacksLib.TradeValueResult memory tvResult,
                    TradingCallbacksLib.PriceImpactResult memory piResult
                ) = TradingCallbacksLib.getTradeAndPriceData(
                    a,
                    t,
                    pairInfos,
                    i.initialLeverage,
                    IOstiumPairsStorage(registry.getContractAddress('pairsStorage')).pairMaxLeverage(t.pairIndex),
                    collateralToClose,
                    true
                );

                uint256 maxSlippage = (wantedPrice * slippageP) / 100 / 100;

                if (t.buy
                        ? piResult.priceAfterImpact < wantedPrice - maxSlippage
                        : piResult.priceAfterImpact > wantedPrice + maxSlippage) {
                    cancelReason = IOstiumTradingCallbacks.CancelReason.SLIPPAGE;
                } else {
                    if (piResult.isDynamic) {
                        _updateDynamicSpreadVolumes(t.pairIndex, false, t.buy, collateralToClose, t.leverage, pairInfos);
                    }

                    bool isLiquidated = tvResult.tradeValue < tvResult.liqMarginValue;

                    (tvResult.profitP,) = TradingCallbacksLib.currentPercentProfit(
                        t.openPrice.toInt256(),
                        piResult.priceAfterImpact.toInt256(),
                        t.buy,
                        int32(t.leverage),
                        int32(i.initialLeverage)
                    );
                    tvResult.tradeValue = pairInfos.getTradeValuePure(
                        collateralToClose, tvResult.profitP, tvResult.rolloverFees, tvResult.fundingFees
                    );

                    IOstiumOpenPnl(registry.getContractAddress('openPnl')).updateAccTotalPnl(
                            a.price,
                            t.openPrice,
                            piResult.priceAfterImpact,
                            i.oiNotional * closePercentage / 100e2,
                            t.pairIndex,
                            t.buy,
                            false
                        );
                    IOstiumOpenPnl(registry.getContractAddress('openPnl')).updateAccClosedRollover(t, closePercentage);

                    uint256 liquidationFee = isLiquidated ? tvResult.tradeValue : 0;

                    unregisterTrade(
                        a.orderId,
                        i.tradeId,
                        t,
                        isLiquidated ? 0 : tvResult.tradeValue,
                        liquidationFee,
                        collateralToClose
                    );

                    emit FeesChargedV2(a.orderId, i.tradeId, t.trader, tvResult.rolloverFees, tvResult.fundingFees);
                    emit MarketCloseExecutedV2(
                        a.orderId,
                        i.tradeId,
                        piResult.priceAfterImpact,
                        piResult.priceImpactP,
                        tvResult.profitP,
                        tvResult.tradeValue,
                        closePercentage
                    );

                    if (closePercentage == 100e2) {
                        // Full close and successfully closed - refund the oracle fee
                        IOstiumPairsStorage pairsStorage =
                            IOstiumPairsStorage(registry.getContractAddress('pairsStorage'));
                        uint256 oracleFee = pairsStorage.pairOracleFee(t.pairIndex);
                        storageT.refundOracleFee(oracleFee);
                        storageT.transferUsdc(address(storageT), t.trader, oracleFee);
                        emit OracleFeeRefunded(i.tradeId, t.trader, t.pairIndex, oracleFee);
                    }
                }
            }
        }

        if (cancelReason != CancelReason.NONE) {
            emit MarketCloseCanceled(a.orderId, i.tradeId, trade.trader, trade.pairIndex, trade.index, cancelReason);
        }

        storageT.clearDeprecatedBeingMarketClosed(trade.trader, trade.pairIndex, trade.index);
        if (cancelReason != CancelReason.WRONG_TRADE) {
            storageT.unregisterTrigger(
                trade.trader, trade.pairIndex, trade.index, IOstiumTradingStorage.LimitOrder.PENDING_CLOSE
            );
        }
        storageT.unregisterPendingMarketOrder(a.orderId, false);
    }
